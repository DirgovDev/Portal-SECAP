-- Somente a administração de permissões: usuário -> projeto -> obras -> campos.
-- Compatível com o ZIP de Acompanhamento; não muda importação, cadastro ou formulários.
begin;
create schema if not exists secap_private;
-- Retira apenas os bloqueios acrescentados nas versões abandonadas nesta conversa.
drop trigger if exists secap_require_change_reason on public.obras;
drop trigger if exists secap_check_work_responsible on public.obras;
drop trigger if exists secap_assign_all_responsibles on public.obras;
do $$ begin if to_regclass('public.secap_work_responsibles') is not null then execute 'drop trigger if exists secap_check_responsible_link on public.secap_work_responsibles';end if;end $$;
create or replace function secap_private.project_allowed(pid text, editing boolean default false)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.profiles p where p.id=auth.uid() and (p.role='administrador' or (p.role='usuario' and (p.project_scope='all' or pid=any(p.project_ids)) and (not editing or p.obras_access='editar'))));
$$;
revoke all on function secap_private.project_allowed(text,boolean) from public,anon;
grant execute on function secap_private.project_allowed(text,boolean) to authenticated;
create or replace function secap_private.obra_allowed(o public.obras,editing boolean default false) returns boolean language plpgsql stable security definer set search_path='' as $$
declare ids jsonb;
begin
 if not secap_private.project_allowed(o.project_id,editing) then return false;end if;
 if public.is_admin() then return true;end if;
 select s.body->'projectWorkAccess'->auth.uid()::text->o.project_id into ids from public.app_state s where s.id=1;
 if ids is null or jsonb_typeof(ids)<>'array' then return false;end if;
 return exists(select 1 from jsonb_array_elements_text(ids) id where id=o.id);
end $$;
revoke all on function secap_private.obra_allowed(public.obras,boolean) from public,anon;
grant execute on function secap_private.obra_allowed(public.obras,boolean) to authenticated;
-- Remove políticas permissivas antigas que poderiam somar acesso por OR.
do $$ declare p record;begin for p in select policyname from pg_policies where schemaname='public' and tablename='obras' loop execute format('drop policy %I on public.obras',p.policyname);end loop;end $$;
alter table public.obras enable row level security;
create policy project_read on public.obras for select to authenticated using(secap_private.obra_allowed(obras,false));
create policy project_insert on public.obras for insert to authenticated with check(secap_private.obra_allowed(obras,true));
create policy project_update on public.obras for update to authenticated using(secap_private.obra_allowed(obras,true)) with check(secap_private.obra_allowed(obras,true));
create policy project_delete on public.obras for delete to authenticated using(secap_private.obra_allowed(obras,true));
create or replace function public.guard_obras_field_permissions()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  member_email text;
  allowed_fields jsonb := '[]'::jsonb;
  field_id text;
  old_keys text[];
  new_keys text[];
  changed_keys text[];
  new_value jsonb;
begin
  if auth.uid() is null or public.is_admin() then
    return new;
  end if;

  select lower(p.email) into member_email
    from public.profiles p
   where p.id = auth.uid() and p.role = 'usuario';

  if member_email is null then
    raise exception 'Usuário não autorizado.' using errcode = '42501';
  end if;

  select coalesce(
    s.body->'fieldPermissions'->member_email->new.project_id,
    '[]'::jsonb
  ) into allowed_fields
    from public.app_state s
   where s.id = 1;

  -- Sem linha em app_state o SELECT acima devolve NULL; NULL nunca pode virar liberação.
  if allowed_fields is null or jsonb_typeof(allowed_fields) <> 'array' then
    allowed_fields := '[]'::jsonb;
  end if;

  if tg_op = 'INSERT' then
    if jsonb_array_length(allowed_fields) = 0 then
      raise exception 'Nenhum campo foi liberado para edição neste projeto.' using errcode = '42501';
    end if;

    -- Campos padrão: valores diferentes dos padrões só podem ser enviados se liberados.
    if new.nome is distinct from '' and not (allowed_fields ? 'nome') then
      raise exception 'Sem permissão para editar o campo nome.' using errcode = '42501';
    end if;
    if new.status is distinct from 'Planejamento' and not (allowed_fields ? 'status') then
      raise exception 'Sem permissão para editar o campo status.' using errcode = '42501';
    end if;
    if new.valor is not null and not (allowed_fields ? 'valor') then
      raise exception 'Sem permissão para editar o campo valor.' using errcode = '42501';
    end if;
    if new.executado is not null and not (allowed_fields ? 'executado') then
      raise exception 'Sem permissão para editar o campo executado.' using errcode = '42501';
    end if;
    if new.prazo is not null and not (allowed_fields ? 'prazo') then
      raise exception 'Sem permissão para editar o campo prazo.' using errcode = '42501';
    end if;
    if new.responsavel is distinct from '' and not (allowed_fields ? 'responsavel') then
      raise exception 'Sem permissão para editar o campo responsavel.' using errcode = '42501';
    end if;
    if coalesce(new.progresso, 0) <> 0 and not (allowed_fields ? 'progresso') then
      raise exception 'Sem permissão para editar o campo progresso.' using errcode = '42501';
    end if;
    if new.proxima is distinct from '' and not (allowed_fields ? 'proxima') then
      raise exception 'Sem permissão para editar o campo proxima.' using errcode = '42501';
    end if;
    if new.orgao is distinct from '' and not (allowed_fields ? 'orgao') then
      raise exception 'Sem permissão para editar o campo orgao.' using errcode = '42501';
    end if;

    -- Campos personalizados são armazenados no objeto JSONB dados.
    for field_id, new_value in select key, value from jsonb_each(coalesce(new.dados, '{}'::jsonb)) loop
      if new_value is distinct from 'null'::jsonb
         and new_value is distinct from '""'::jsonb
         and not (allowed_fields ? field_id) then
        raise exception 'Sem permissão para editar o campo personalizado %.', field_id using errcode = '42501';
      end if;
    end loop;

    if coalesce(new.nome_planilha, '') <> '' or new.planilha_id is not null then
      raise exception 'Somente o administrador pode importar planilhas.' using errcode = '42501';
    end if;
    return new;
  end if;

  -- Impede mover ou trocar a identidade/origem da obra por uma atualização de campo.
  if new.id is distinct from old.id or new.project_id is distinct from old.project_id
     or new.nome_planilha is distinct from old.nome_planilha
     or new.planilha_id is distinct from old.planilha_id then
    raise exception 'Não é permitido alterar a identificação ou a origem da obra.' using errcode = '42501';
  end if;

  foreach field_id in array array['nome','status','valor','executado','prazo','responsavel','progresso','proxima','orgao'] loop
    if (to_jsonb(old)->field_id) is distinct from (to_jsonb(new)->field_id)
       and not (allowed_fields ? field_id) then
      raise exception 'Sem permissão para editar o campo %.', field_id using errcode = '42501';
    end if;
  end loop;

  select coalesce(array_agg(key), '{}'::text[]) into old_keys
    from jsonb_object_keys(coalesce(old.dados, '{}'::jsonb)) as keys(key);
  select coalesce(array_agg(key), '{}'::text[]) into new_keys
    from jsonb_object_keys(coalesce(new.dados, '{}'::jsonb)) as keys(key);
  select coalesce(array_agg(distinct field_key), '{}'::text[]) into changed_keys
    from unnest(old_keys || new_keys) as changed(field_key);
  foreach field_id in array changed_keys loop
    if (old.dados->field_id) is distinct from (new.dados->field_id)
       and not (allowed_fields ? field_id) then
      raise exception 'Sem permissão para editar o campo personalizado %.', field_id using errcode = '42501';
    end if;
  end loop;

  return new;
end;
$$;
revoke all on function public.guard_obras_field_permissions() from public, anon, authenticated;
drop trigger if exists obras_field_permissions_guard on public.obras;
create trigger obras_field_permissions_guard
  before insert or update on public.obras
  for each row execute function public.guard_obras_field_permissions();

-- Exclusão de obras: quem não tem nenhum campo liberado no projeto não pode excluir.
-- (A mesma regra de "nenhum campo liberado = nenhuma alteração" vale para criar e para excluir.)
create or replace function public.secap_read_state()
 returns jsonb
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare body_value jsonb; personal jsonb; member_email text;
begin
 if not public.is_member() then raise exception 'Acesso não aprovado.' using errcode='42501';end if;
 select body into body_value from public.app_state where id=1;
 if body_value is null then return body_value;end if;
 if public.is_admin() then return jsonb_set(body_value,'{logs}','[]'::jsonb);end if;
 select body into personal from public.secap_member_state where owner=auth.uid();
 select lower(email) into member_email from public.profiles where id=auth.uid();
 return jsonb_build_object(
   'projects',coalesce((select jsonb_agg((p-'records')||jsonb_build_object('records','[]'::jsonb)) from jsonb_array_elements(body_value->'projects') p where secap_private.project_allowed(p->>'id')),'[]'),
   'users','[]'::jsonb,
   'notes',coalesce(personal->'notes','[]'::jsonb),
   'terms','[]'::jsonb,
   'logs','[]'::jsonb,
   -- O usuário recebe apenas as próprias regras, nunca as permissões dos demais.
   'projectWorkAccess',jsonb_build_object(auth.uid()::text,coalesce(body_value->'projectWorkAccess'->auth.uid()::text,'{}'::jsonb)),
   'fieldPermissions',jsonb_build_object(member_email,coalesce(body_value->'fieldPermissions'->member_email,'{}'::jsonb)),
   'rowFilters',jsonb_build_object(member_email,coalesce(body_value->'rowFilters'->member_email,'{}'::jsonb))
 );
end$function$;

-- Lista completa em páginas explícitas: independente dos filtros da tela e limite da API.
create or replace function public.secap_admin_permission_works(p_project text,p_offset integer default 0) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare fid text;
begin
 if auth.uid() is null or not coalesce(public.is_admin(),false) then raise exception 'Acesso restrito.' using errcode='42501';end if;
 if p_offset is null or p_offset<0 then raise exception 'Página inválida.';end if;
 select f->>'id' into fid
   from public.app_state s
   cross join lateral jsonb_array_elements(coalesce(s.body->'projects','[]')) p
   cross join lateral jsonb_array_elements(coalesce(p->'fields','[]')) f
  where s.id=1 and p->>'id'=p_project and lower(f->>'name') ~ '^respons.vel\s+(pelo\s+)?acompanhamento'
  limit 1;
 return jsonb_build_object(
   'total',(select count(*) from public.obras where project_id=p_project),
   'acompanhamentoField',fid,
   'rows',(select coalesce(jsonb_agg(to_jsonb(w) order by w.id),'[]') from(
     select id,nome,coalesce(dados->>'codigo',dados->>'ID',id) as codigo,
            case when fid is null then null else nullif(trim(dados->>fid),'') end as acompanhamento
       from public.obras where project_id=p_project order by id limit 500 offset p_offset)w));
end $$;
create or replace function public.secap_admin_permission_context() returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not coalesce(public.is_admin(),false) then raise exception 'Acesso restrito.' using errcode='42501';end if;
 return jsonb_build_object('users',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'email',email,'role',role,'projectScope',project_scope,'projectIds',project_ids,'obrasAccess',obras_access) order by name,id),'[]') from public.profiles where role in ('administrador','usuario')),'works',(select coalesce(body->'projectWorkAccess','{}') from public.app_state where id=1),'fields',(select coalesce(body->'fieldPermissions','{}') from public.app_state where id=1));
end $$;
create or replace function secap_private.require_work_responsible() returns trigger
language plpgsql security definer set search_path='' as $$
declare owner_key text; owner_value text; names text[];
begin
 if public.is_admin() and coalesce(current_setting('secap.responsible_sync',true),'')='true' then return new;end if;
 select coalesce(nullif(p->'biMapping'->>'owner',''),'responsavel') into owner_key
 from public.app_state state cross join lateral jsonb_array_elements(coalesce(state.body->'projects','[]'::jsonb)) p
 where state.id=1 and p->>'id'=new.project_id limit 1;
 owner_key:=coalesce(owner_key,'responsavel');
 owner_value:=case when owner_key='responsavel' then new.responsavel else coalesce(new.dados->>owner_key,new.responsavel) end;
 names:=array(select btrim(name) from regexp_split_to_table(coalesce(owner_value,''),'[;\n]+') name
 where btrim(name)<>'' and lower(btrim(name)) not in ('—','-','sem responsável','sem responsavel','não informado','nao informado'));
 if coalesce(array_length(names,1),0)=0 then raise exception 'É obrigatório informar pelo menos um responsável pela obra.' using errcode='23514';end if;
 if array_length(names,1)>100 or exists(select 1 from unnest(names) name where char_length(name)>254) then raise exception 'Confira os responsáveis: até 100 nomes com até 254 caracteres cada.' using errcode='23514';end if;
 return new;
end $$;
revoke all on function secap_private.require_work_responsible() from public,anon,authenticated;
-- Deriva os responsáveis das mesmas seleções usadas para liberar obras.
create or replace function secap_private.sync_work_responsibles(pid text,work_ids text[]) returns void language plpgsql security definer set search_path='' as $$
declare state jsonb; owner_key text; item record; label text; previous_sync text; previous_reason text;
begin
 select body into state from public.app_state where id=1;
 select coalesce(nullif(p->'biMapping'->>'owner',''),'responsavel') into owner_key from jsonb_array_elements(state->'projects') p where p->>'id'=pid;
 owner_key:=coalesce(owner_key,'responsavel');
 previous_sync:=coalesce(current_setting('secap.responsible_sync',true),'');previous_reason:=coalesce(current_setting('secap.change_reason',true),'');
 perform set_config('secap.responsible_sync','true',true);perform set_config('secap.change_reason','Atribuição de responsáveis pelas permissões do projeto',true);
 for item in select * from public.obras where project_id=pid and id=any(work_ids) order by id for update loop
  select coalesce(string_agg(coalesce(nullif(btrim(p.name),''),p.email),'; ' order by lower(p.name),p.id),'') into label
  from jsonb_each(coalesce(state->'projectWorkAccess','{}')) link join public.profiles p on p.id::text=link.key
  where p.role in ('administrador','usuario') and jsonb_typeof(link.value->pid)='array' and (link.value->pid)?item.id;
  if item.responsavel is distinct from label or (owner_key<>'responsavel' and item.dados->>owner_key is distinct from label) then
   update public.obras set responsavel=label,dados=case when owner_key<>'responsavel' then jsonb_set(coalesce(dados,'{}'),array[owner_key],to_jsonb(label)) else dados end,updated_at=now() where id=item.id;
  end if;
 end loop;
 perform set_config('secap.responsible_sync',previous_sync,true);perform set_config('secap.change_reason',previous_reason,true);
end $$;
revoke all on function secap_private.sync_work_responsibles(text,text[]) from public,anon,authenticated;
create or replace function public.secap_admin_save_project_permissions(p_user uuid,p_project text,p_works text[],p_fields text[]) returns boolean language plpgsql security definer set search_path='' as $$
declare state jsonb; project jsonb; email_value text; selected text[]; previous_works text[];
begin
 if auth.uid() is null or not coalesce(public.is_admin(),false) then raise exception 'Acesso restrito.' using errcode='42501';end if;
 select lower(email) into email_value from public.profiles where id=p_user and role in ('administrador','usuario');
 if not found or p_works is null or p_fields is null then raise exception 'Selecione uma conta aprovada, obras e campos.';end if;
 select body into state from public.app_state where id=1 for update;
 select p into project from jsonb_array_elements(state->'projects')p where p->>'id'=p_project;
 if project is null then raise exception 'Projeto não encontrado.';end if;
 if exists(select 1 from unnest(p_works)w where not exists(select 1 from public.obras where id=w and project_id=p_project)) then raise exception 'Obra inválida para este projeto.';end if;
 if exists(select 1 from unnest(p_fields)f where not exists(select 1 from jsonb_array_elements(coalesce(project->'fields','[]'))meta where meta->>'id'=f)) then raise exception 'Campo inválido para este projeto.';end if;
 select coalesce(array_agg(v),'{}') into previous_works from jsonb_array_elements_text(case when jsonb_typeof(state->'projectWorkAccess'->p_user::text->p_project)='array' then state->'projectWorkAccess'->p_user::text->p_project else '[]'::jsonb end) v;
 select coalesce(array_agg(distinct w),'{}') into selected from unnest(p_works)w;
 state:=jsonb_set(state,'{projectWorkAccess}',coalesce(state->'projectWorkAccess','{}'));
 state:=jsonb_set(state,array['projectWorkAccess',p_user::text],coalesce(state->'projectWorkAccess'->p_user::text,'{}'));
 state:=jsonb_set(state,array['projectWorkAccess',p_user::text,p_project],to_jsonb(selected));
 state:=jsonb_set(state,'{fieldPermissions}',coalesce(state->'fieldPermissions','{}'));
 state:=jsonb_set(state,array['fieldPermissions',email_value],coalesce(state->'fieldPermissions'->email_value,'{}'));
 state:=jsonb_set(state,array['fieldPermissions',email_value,p_project],to_jsonb(p_fields));
 state:=jsonb_set(state,'{logs}',coalesce(state->'logs','[]')||jsonb_build_array(jsonb_build_object('id',gen_random_uuid()::text,'at',clock_timestamp(),'user',auth.uid(),'who',(select name from public.profiles where id=auth.uid()),'project',p_project,'projectName',project->>'name','action','Configurou permissões do projeto','field','Obras e campos permitidos','after',jsonb_build_object('usuario',p_user,'obras',selected,'campos',p_fields))));
 update public.app_state set body=state,updated_at=now() where id=1;
 update public.profiles set project_ids=case when project_scope='all' or p_project=any(project_ids) then project_ids else array_append(project_ids,p_project) end,obras_access=case when cardinality(p_fields)>0 then 'editar' else obras_access end where id=p_user;
 perform secap_private.sync_work_responsibles(p_project,previous_works || selected);
 return true;
end $$;
revoke all on function public.secap_admin_permission_context(),public.secap_admin_permission_works(text,integer),public.secap_admin_save_project_permissions(uuid,text,text[],text[]) from public,anon;
grant execute on function public.secap_admin_permission_context(),public.secap_admin_permission_works(text,integer),public.secap_admin_save_project_permissions(uuid,text,text[],text[]) to authenticated;
create or replace function public.secap_my_work_selection() returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not coalesce(public.is_member(),false) then raise exception 'Acesso não aprovado.' using errcode='42501';end if;
 return jsonb_build_object(auth.uid()::text,coalesce((select body->'projectWorkAccess'->auth.uid()::text from public.app_state where id=1),'{}'::jsonb));
end $$;
revoke all on function public.secap_admin_permission_context(),public.secap_my_work_selection() from public,anon;
grant execute on function public.secap_admin_permission_context(),public.secap_my_work_selection() to authenticated;
create or replace function public.secap_work_responsible_labels(p_project text) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not coalesce(public.is_member(),false) then raise exception 'Acesso não aprovado.' using errcode='42501';end if;
 return (select coalesce(jsonb_agg(jsonb_build_object('id',o.id,'responsavel',o.responsavel) order by o.id),'[]') from public.obras o where o.project_id=p_project and secap_private.obra_allowed(o,false));
end $$;
revoke all on function public.secap_work_responsible_labels(text) from public,anon;
grant execute on function public.secap_work_responsible_labels(text) to authenticated;
-- Aplica também às seleções que o administrador já havia salvo.
do $$ declare project record;ids text[];begin
 if public.is_admin() or auth.uid() is null then
  for project in select p->>'id' as id from public.app_state s cross join lateral jsonb_array_elements(s.body->'projects')p where s.id=1 loop
   select coalesce(array_agg(distinct id),'{}') into ids from public.app_state s cross join lateral jsonb_each(coalesce(s.body->'projectWorkAccess','{}'))link cross join lateral jsonb_array_elements_text(case when jsonb_typeof(link.value->project.id)='array' then link.value->project.id else '[]'::jsonb end)id where s.id=1;
   perform secap_private.sync_work_responsibles(project.id,ids);
  end loop;
 end if;
end $$;
notify pgrst,'reload schema';
commit;
select 'Permissões do projeto atualizadas com sucesso' as resultado;
