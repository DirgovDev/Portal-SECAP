-- Responsáveis pela seleção administrativa de obras.
begin;
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
revoke all on function public.secap_admin_save_project_permissions(uuid,text,text[],text[]) from public,anon;
grant execute on function public.secap_admin_save_project_permissions(uuid,text,text[],text[]) to authenticated;
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
select 'Responsáveis sincronizados com as permissões do projeto' as resultado;
