-- Aplicar uma vez no MESMO banco utilizado por este portal, depois de project_access.sql.
-- Não remove registros. A consulta completa é exclusiva de administradores.
begin;
create or replace function public.secap_read_state() returns jsonb language plpgsql security definer set search_path='' as $$
declare body_value jsonb; personal jsonb; member_email text;
begin
 if not public.is_member() then raise exception 'Acesso não aprovado.' using errcode='42501';end if;
 select body into body_value from public.app_state where id=1;
 if body_value is null then return body_value;end if;
 if public.is_admin() then return jsonb_set(body_value,'{logs}','[]'::jsonb);end if;
 select body into personal from public.secap_member_state where owner=auth.uid();
 select lower(email) into member_email from public.profiles where id=auth.uid();
 return jsonb_build_object(
   'projects',coalesce((select jsonb_agg(p) from jsonb_array_elements(body_value->'projects') p where secap_private.project_allowed(p->>'id')),'[]'),
   'users','[]'::jsonb,
   'notes',coalesce(personal->'notes','[]'::jsonb),
   'terms','[]'::jsonb,
   'logs','[]'::jsonb,
   -- O usuário recebe apenas as próprias regras, nunca as permissões dos demais.
   'fieldPermissions',jsonb_build_object(member_email,coalesce(body_value->'fieldPermissions'->member_email,'{}'::jsonb))
 );
end$$;
-- Nome de exibição: dados cadastrais; nunca usado para conceder permissões.
create or replace function secap_private.audit_actor_name(actor_id uuid, actor_email text default null) returns text
language sql stable security definer set search_path='' as $$
 select coalesce(
  (select nullif(btrim(p.name),'') from public.profiles p where (p.id=actor_id or (actor_id is null and lower(p.email)=lower(actor_email))) and position('@' in p.name)=0),
  (select nullif(btrim(r.name),'') from public.account_requests r where lower(r.email)=lower(coalesce((select p.email from public.profiles p where p.id=actor_id),case when position('@' in actor_email)>0 then actor_email end)) and position('@' in r.name)=0 order by r.created_at desc limit 1),
  (select coalesce(nullif(btrim(u.raw_user_meta_data->>'name'),''),nullif(btrim(u.raw_user_meta_data->>'full_name'),'')) from auth.users u where u.id=actor_id),
  'Nome não informado');
$$;
revoke all on function secap_private.audit_actor_name(uuid,text) from public,anon,authenticated;

-- Resolve somente identificadores de autoria existentes, sem adivinhar usuários.
create or replace function secap_private.audit_entry_name(entry jsonb) returns text
language plpgsql stable security definer set search_path='' as $$
declare actor_id uuid; stored_name text; actor_email text; resolved text;
begin
 stored_name:=btrim(coalesce(entry->>'who',''));
 if stored_name<>'' and stored_name not in ('Nome não informado','Usuário não informado') and position('@' in stored_name)=0 then return stored_name;end if;
 if coalesce(entry->>'user','') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then actor_id:=(entry->>'user')::uuid;end if;
 actor_email:=case when position('@' in stored_name)>0 then stored_name when position('@' in coalesce(entry->>'email',''))>0 then entry->>'email' end;
 resolved:=secap_private.audit_actor_name(actor_id,actor_email);
 return resolved;
end $$;
revoke all on function secap_private.audit_entry_name(jsonb) from public,anon,authenticated;

-- Histórico protegido de alterações de campos das obras.
create table if not exists public.secap_audit_events (
 id uuid primary key default gen_random_uuid(),
 at timestamptz not null default clock_timestamp(),
 actor uuid, who text not null, project_id text not null, project_name text not null,
 record_id text not null, record_name text not null,
 field_id text not null, field_name text not null,
 before_value jsonb, after_value jsonb,
 before_present boolean not null, after_present boolean not null,
 action text not null default 'Alterou campo', recovered_from uuid unique references public.secap_audit_events(id)
);
alter table public.secap_audit_events enable row level security;
revoke all on public.secap_audit_events from public,anon,authenticated;
drop policy if exists audit_admin_read on public.secap_audit_events;
create policy audit_admin_read on public.secap_audit_events for select to authenticated using(public.is_admin());
grant select on public.secap_audit_events to authenticated;
create index if not exists secap_audit_at_idx on public.secap_audit_events(at desc);
create or replace function secap_private.capture_obra_audit() returns trigger
language plpgsql security definer set search_path='' as $$
declare old_flat jsonb; new_flat jsonb; k text; pname text; fname text; actor_name text;
begin
 old_flat := old.dados || (to_jsonb(old) - 'dados');
 new_flat := new.dados || (to_jsonb(new) - 'dados');
 select secap_private.audit_actor_name(auth.uid()) into actor_name;
 select p->>'name' into pname from public.app_state s cross join lateral jsonb_array_elements(s.body->'projects') p where s.id=1 and p->>'id'=new.project_id;
 for k in select jsonb_object_keys(old_flat || new_flat) loop
  if k = any(array['id','project_id','created_at','updated_at']) then continue; end if;
  if (old_flat->k) is not distinct from (new_flat->k) and (old_flat ? k) = (new_flat ? k) then continue;end if;
  select f->>'name' into fname from public.app_state s cross join lateral jsonb_array_elements(s.body->'projects') p
   cross join lateral jsonb_array_elements(coalesce(p->'fields','[]'::jsonb)) f where s.id=1 and p->>'id'=new.project_id and f->>'id'=k limit 1;
  insert into public.secap_audit_events(actor,who,project_id,project_name,record_id,record_name,field_id,field_name,before_value,after_value,before_present,after_present,action,recovered_from)
   values(auth.uid(),coalesce(actor_name,'Sistema'),new.project_id,coalesce(pname,new.project_id),new.id,new.nome,k,coalesce(fname,k),old_flat->k,new_flat->k,old_flat ? k,new_flat ? k,
    case when nullif(current_setting('secap.recovery_event',true),'') is null then 'Alterou campo' else 'Recuperou informação anterior' end,
    nullif(current_setting('secap.recovery_event',true),'')::uuid);
 end loop;
 return new;
end $$;
revoke all on function secap_private.capture_obra_audit() from public,anon,authenticated;
drop trigger if exists secap_capture_audit on public.obras;
create trigger secap_capture_audit after update on public.obras for each row execute function secap_private.capture_obra_audit();

create or replace function public.secap_recover_audit(event_id uuid, agreement boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare e public.secap_audit_events%rowtype; r public.obras%rowtype; flat jsonb; patch jsonb; standard boolean; restored public.obras%rowtype;
begin
 if auth.uid() is null or not coalesce(public.is_admin(),false) then raise exception 'Acesso restrito aos administradores.' using errcode='42501';end if;
 if agreement is distinct from true then raise exception 'Confirme: Concordo em voltar.';end if;
 select * into e from public.secap_audit_events where id=event_id for update;
 if not found then raise exception 'Registro de auditoria não encontrado.';end if;
 if exists(select 1 from public.secap_audit_events where recovered_from=event_id) then raise exception 'Esta alteração já foi recuperada.';end if;
 select * into r from public.obras where id=e.record_id and project_id=e.project_id for update;
 if not found then raise exception 'A obra não existe neste projeto. Não é possível recuperar automaticamente.';end if;
 flat := r.dados || (to_jsonb(r)-'dados');
 if (flat->e.field_id) is distinct from e.after_value or (flat ? e.field_id) is distinct from e.after_present then
  raise exception 'O campo mudou depois desta alteração. Atualize a auditoria; a recuperação foi cancelada para não sobrescrever informações mais recentes.' using errcode='40001';
 end if;
 if e.field_id=any(array['id','project_id','created_at','updated_at']) then raise exception 'Campo protegido.';end if;
 standard := (to_jsonb(r)-'dados') ? e.field_id;
 if standard then
  patch := jsonb_build_object(e.field_id,e.before_value);
 else
  patch := jsonb_build_object('dados',case when e.before_present then jsonb_set(r.dados,array[e.field_id],coalesce(e.before_value,'null'::jsonb),true) else r.dados-e.field_id end);
 end if;
 restored := jsonb_populate_record(r,patch);
 perform set_config('secap.recovery_event',event_id::text,true);
 update public.obras set nome=restored.nome,status=restored.status,valor=restored.valor,executado=restored.executado,prazo=restored.prazo,
 responsavel=restored.responsavel,progresso=restored.progresso,proxima=restored.proxima,orgao=restored.orgao,dados=restored.dados,
 nome_planilha=restored.nome_planilha,planilha_id=restored.planilha_id,updated_at=clock_timestamp() where id=r.id returning * into restored;
 perform set_config('secap.recovery_event','',true);
 return jsonb_build_object('ok',true,'obra',to_jsonb(restored),'recovered_event',event_id);
end $$;
revoke all on function public.secap_recover_audit(uuid,boolean) from public,anon;
grant execute on function public.secap_recover_audit(uuid,boolean) to authenticated;

create or replace function public.secap_audit_logs() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare result jsonb;
begin
  if auth.uid() is null or not coalesce(public.is_admin(),false) then
    raise exception 'Auditoria disponível apenas para administradores.' using errcode='42501';
  end if;
  select coalesce(jsonb_agg(entry order by entry->>'at' desc), '[]'::jsonb) into result
  from (
    select distinct entry from (
      select jsonb_build_object('id','server:'||e.id::text,'eventId',e.id,'at',e.at,'who',case when position('@' in e.who)>0 or btrim(e.who) in ('','Nome não informado','Usuário não informado') then secap_private.audit_actor_name(e.actor,e.who) else e.who end,'action',e.action,
        'project',e.project_id,'projectName',e.project_name,'recordId',e.record_id,'recordName',e.record_name,
        'field',e.field_name,'fieldId',e.field_id,'before',e.before_value,'after',e.after_value,
        'recoveredFrom',e.recovered_from,
        'recovered',exists(select 1 from public.secap_audit_events recovery where recovery.recovered_from=e.id),
        'recoverable',not exists(select 1 from public.secap_audit_events recovery where recovery.recovered_from=e.id)) as entry
      from public.secap_audit_events e
      union all
      select l.value as entry from public.app_state s
      cross join lateral jsonb_array_elements(coalesce(s.body->'logs','[]'::jsonb)) l
      where s.id=1
      union all
      select l.value || jsonb_build_object('user',m.owner::text,
        'who',secap_private.audit_actor_name(m.owner,p.email)) as entry
      from public.secap_member_state m
      left join public.profiles p on p.id=m.owner
      cross join lateral jsonb_array_elements(coalesce(m.body->'logs','[]'::jsonb)) l
    ) entries
  ) unique_entries;
  return result;
end $$;
revoke all on function public.secap_audit_logs() from public, anon;
grant execute on function public.secap_audit_logs() to authenticated;
create or replace function public.secap_save_project_state(projects jsonb, expected_projects jsonb, personal_state jsonb default '{}') returns boolean language plpgsql security definer set search_path='' as $$
declare saved jsonb; current_visible jsonb; next_projects jsonb; item jsonb;
begin
 if not public.is_member() or public.is_admin() then raise exception 'Operação inválida.' using errcode='42501';end if;
 if jsonb_typeof(projects)<>'array' or jsonb_typeof(expected_projects)<>'array' then raise exception 'Projetos inválidos.';end if;
 select body into saved from public.app_state where id=1 for update;
 select coalesce(jsonb_agg(p),'[]') into current_visible from jsonb_array_elements(saved->'projects') p where secap_private.project_allowed(p->>'id');
 if current_visible is distinct from expected_projects then raise exception 'Os projetos ou suas permissões mudaram. Recarregue antes de salvar.' using errcode='40001';end if;
 if (select coalesce(jsonb_agg(p->>'id' order by p->>'id'),'[]') from jsonb_array_elements(projects) p) is distinct from (select coalesce(jsonb_agg(p->>'id' order by p->>'id'),'[]') from jsonb_array_elements(current_visible) p) then raise exception 'Somente administradores podem criar ou excluir pastas de projeto.' using errcode='42501';end if;
 for item in select value from jsonb_array_elements(projects) loop
  if (item - 'records') is distinct from (select p - 'records' from jsonb_array_elements(current_visible) p where p->>'id'=item->>'id') and not secap_private.project_allowed(item->>'id',true) then raise exception 'Você não pode editar este projeto.' using errcode='42501';end if;
 end loop;
 select jsonb_agg(coalesce((select n - 'records' || '{"records":[]}'::jsonb from jsonb_array_elements(projects) n where n->>'id'=p->>'id'),p)) into next_projects from jsonb_array_elements(saved->'projects') p;
 update public.app_state set body=jsonb_set(saved,'{projects}',coalesce(next_projects,'[]')),updated_at=now() where id=1;
 if jsonb_typeof(coalesce(personal_state->'notes','[]'))<>'array' or jsonb_typeof(coalesce(personal_state->'logs','[]'))<>'array' then raise exception 'Dados pessoais inválidos.';end if;
 insert into public.secap_member_state(owner,body) values(auth.uid(),jsonb_build_object('notes',coalesce(personal_state->'notes','[]'),'logs',coalesce(personal_state->'logs','[]'))) on conflict(owner) do update set body=jsonb_set(excluded.body,'{logs}',
   (select coalesce(jsonb_agg(entry),'[]'::jsonb) from
     (select distinct value as entry from jsonb_array_elements(
       coalesce(public.secap_member_state.body->'logs','[]'::jsonb) || coalesce(excluded.body->'logs','[]'::jsonb)
     )) preserved_logs));
 return true;
end$$;
-- Índice dos registros legados: migração preserva o histórico e evita ler JSONs inteiros em cada página.
create table if not exists public.secap_audit_legacy(id text primary key, at timestamptz not null, entry jsonb not null);
alter table public.secap_audit_legacy enable row level security;
revoke all on public.secap_audit_legacy from public,anon,authenticated;
drop policy if exists audit_legacy_admin_read on public.secap_audit_legacy;
create policy audit_legacy_admin_read on public.secap_audit_legacy for select to authenticated using(public.is_admin());
grant select on public.secap_audit_legacy to authenticated;
create index if not exists secap_audit_legacy_at_idx on public.secap_audit_legacy(at desc,id desc);
create index if not exists secap_audit_events_page_idx on public.secap_audit_events(at desc,id desc);
create or replace function secap_private.index_legacy_audit(entries jsonb, owner_id uuid default null) returns void
language plpgsql security definer set search_path='' as $$
declare e jsonb; stamp timestamptz; actor_name text;
begin
 if jsonb_typeof(entries) is distinct from 'array' then return;end if;
 if owner_id is not null then select secap_private.audit_actor_name(owner_id) into actor_name;end if;
 for e in select value from jsonb_array_elements(entries) loop
  begin stamp := (e->>'at')::timestamptz;exception when others then stamp:=null;end;
  if stamp is null then continue;end if;
  if owner_id is not null then e:=e || jsonb_build_object('user',owner_id,'who',coalesce(actor_name,e->>'who','Usuário não informado'));end if;
  insert into public.secap_audit_legacy(id,at,entry)
   values(coalesce(nullif(e->>'id',''),md5(e::text)),stamp,e) on conflict(id) do nothing;
 end loop;
end $$;
revoke all on function secap_private.index_legacy_audit(jsonb,uuid) from public,anon,authenticated;
do $$begin
 perform secap_private.index_legacy_audit(body->'logs') from public.app_state where id=1;
 perform secap_private.index_legacy_audit(body->'logs',owner) from public.secap_member_state;
end $$;
create or replace function secap_private.capture_legacy_audit() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if tg_table_name='app_state' then
  if tg_op='UPDATE' then perform secap_private.index_legacy_audit(old.body->'logs');end if;
  perform secap_private.index_legacy_audit(new.body->'logs');
 else
  if tg_op='UPDATE' then perform secap_private.index_legacy_audit(old.body->'logs',old.owner);end if;
  perform secap_private.index_legacy_audit(new.body->'logs',new.owner);
 end if;
 return new;
end $$;
revoke all on function secap_private.capture_legacy_audit() from public,anon,authenticated;
drop trigger if exists secap_index_audit_state on public.app_state;
create trigger secap_index_audit_state after insert or update of body on public.app_state for each row execute function secap_private.capture_legacy_audit();
drop trigger if exists secap_index_audit_member on public.secap_member_state;
create trigger secap_index_audit_member after insert or update of body on public.secap_member_state for each row execute function secap_private.capture_legacy_audit();

create or replace function public.secap_audit_page(
 p_view text default 'recent', p_start date default null, p_end date default null,
 p_before_at timestamptz default null, p_before_id text default null, p_archive_end date default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare first_day date; last_day date; cutoff date; lower_at timestamptz; upper_at timestamptz;
 selected_lower timestamptz; selected_upper timestamptz; available_start timestamptz; available_end timestamptz;
 page_rows jsonb; has_more boolean; tail jsonb;
begin
 if auth.uid() is null or not coalesce(public.is_admin(),false) then raise exception 'Auditoria restrita aos administradores.' using errcode='42501';end if;
 if p_view not in ('recent','archive') or p_view is null then raise exception 'Período inválido.';end if;
 cutoff := (current_timestamp at time zone 'America/Sao_Paulo')::date-39;
 if p_view='recent' then first_day:=cutoff;last_day:=cutoff+39;
 else last_day:=least(coalesce(p_archive_end,cutoff-1),cutoff-1);first_day:=last_day-39;end if;
 if (p_start is null) <> (p_end is null) or p_start>p_end then raise exception 'Intervalo de datas inválido.';end if;
 if (p_before_at is null) <> (p_before_id is null) then raise exception 'Página inválida.';end if;
 lower_at := first_day::timestamp at time zone 'America/Sao_Paulo';
 upper_at := (last_day+1)::timestamp at time zone 'America/Sao_Paulo';
 selected_lower:=greatest(lower_at,coalesce(p_start::timestamp at time zone 'America/Sao_Paulo',lower_at));
 selected_upper:=least(upper_at,coalesce((p_end+1)::timestamp at time zone 'America/Sao_Paulo',upper_at));
 select min(stamp),max(stamp) into available_start,available_end from (
  select min(at) as stamp from public.secap_audit_events where at>=lower_at and at<upper_at union all
  select max(at) from public.secap_audit_events where at>=lower_at and at<upper_at union all
  select min(at) from public.secap_audit_legacy where at>=lower_at and at<upper_at union all
  select max(at) from public.secap_audit_legacy where at>=lower_at and at<upper_at
 ) bounds;
 with candidates as (
  (select e.at,'server:'||e.id::text as sort_id,jsonb_build_object('id','server:'||e.id::text,'eventId',e.id,'at',e.at,'who',case when position('@' in e.who)>0 or btrim(e.who) in ('','Nome não informado','Usuário não informado') then secap_private.audit_actor_name(e.actor,e.who) else e.who end,'action',e.action,
   'project',e.project_id,'projectName',e.project_name,'recordId',e.record_id,'recordName',e.record_name,'field',e.field_name,'fieldId',e.field_id,
   'before',e.before_value,'after',e.after_value,'recoveredFrom',e.recovered_from,
   'recovered',exists(select 1 from public.secap_audit_events r where r.recovered_from=e.id),
   'recoverable',not exists(select 1 from public.secap_audit_events r where r.recovered_from=e.id)) as entry
   from public.secap_audit_events e where e.at>=selected_lower and e.at<selected_upper
   and (p_before_at is null or (e.at,'server:'||e.id::text)<(p_before_at,p_before_id)) order by e.at desc,e.id desc limit 51)
  union all
  (select l.at,'legacy:'||l.id,l.entry || jsonb_build_object('id','legacy:'||l.id,'at',l.at,'recoverable',false,'eventId',null,'who',secap_private.audit_entry_name(l.entry)) from public.secap_audit_legacy l
   where l.at>=selected_lower and l.at<selected_upper
   and (p_before_at is null or (l.at,'legacy:'||l.id)<(p_before_at,p_before_id)) order by l.at desc,l.id desc limit 51)
 ), limited as (select * from candidates order by at desc,sort_id desc limit 51)
 select coalesce(jsonb_agg(entry order by at desc,sort_id desc),'[]'::jsonb) into page_rows from limited;
 has_more:=jsonb_array_length(page_rows)>50;
 if has_more then page_rows:=page_rows-50;end if;
 tail:=page_rows->(jsonb_array_length(page_rows)-1);
 return jsonb_build_object('rows',page_rows,'hasMore',has_more,'nextCursor',case when has_more then jsonb_build_object('at',tail->'at','id',tail->'id') else null end,
  'periodStart',first_day,'periodEnd',last_day,
  'availableStart',(available_start at time zone 'America/Sao_Paulo')::date,'availableEnd',(available_end at time zone 'America/Sao_Paulo')::date,
  'availableDates',(select coalesce(jsonb_agg(d::date order by d),'[]'::jsonb)
    from generate_series(first_day::timestamp,last_day::timestamp,interval '1 day') d
    where exists(select 1 from public.secap_audit_events e where e.at>=(d at time zone 'America/Sao_Paulo') and e.at<((d+interval '1 day') at time zone 'America/Sao_Paulo'))
       or exists(select 1 from public.secap_audit_legacy l where l.at>=(d at time zone 'America/Sao_Paulo') and l.at<((d+interval '1 day') at time zone 'America/Sao_Paulo'))));
end $$;
revoke all on function public.secap_audit_page(text,date,date,timestamptz,text,date) from public,anon;
grant execute on function public.secap_audit_page(text,date,date,timestamptz,text,date) to authenticated;


-- Atualiza apenas o nome da própria conta autenticada; não altera funções ou permissões.
create or replace function public.secap_update_my_name(new_name text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare clean_name text; changed_name text;
begin
 if auth.uid() is null or not coalesce(public.is_member(),false) then raise exception 'Acesso não aprovado.' using errcode='42501';end if;
 clean_name:=btrim(new_name);
 if clean_name is null or clean_name='' or char_length(clean_name)>120 then raise exception 'Informe um nome válido com até 120 caracteres.';end if;
 update public.profiles set name=clean_name where id=auth.uid() returning name into changed_name;
 if not found then raise exception 'Perfil da conta não encontrado.';end if;
 return jsonb_build_object('name',changed_name);
end $$;
revoke all on function public.secap_update_my_name(text) from public,anon;
grant execute on function public.secap_update_my_name(text) to authenticated;

commit;

select 'Atualização da Auditoria aplicada com sucesso' as resultado;
