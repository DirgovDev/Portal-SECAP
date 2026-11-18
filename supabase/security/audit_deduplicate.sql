-- Unifica apenas o resumo vinculado a um evento real. Não apaga o histórico.
begin;
create schema if not exists secap_private;
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

create or replace function secap_private.audit_is_bi(entry jsonb) returns boolean
language sql immutable set search_path='' as $$ select coalesce(entry->>'source'='bi',false) or coalesce(entry->>'action','') ~* '\mBI\M' $$;
revoke all on function secap_private.audit_is_bi(jsonb) from public,anon,authenticated;
-- Vincula o resumo à alteração real sem remover os registros originais.
create table if not exists secap_private.audit_batch_links (
 log_id text not null references public.secap_audit_legacy(id) on delete cascade,
 change_index bigint not null,
 event_id uuid not null references public.secap_audit_events(id),
 primary key(log_id,change_index)
);
alter table secap_private.audit_batch_links enable row level security;
revoke all on secap_private.audit_batch_links from public,anon,authenticated;
create index if not exists audit_batch_links_event_idx on secap_private.audit_batch_links(event_id);
create index if not exists secap_audit_match_idx on public.secap_audit_events(project_id,record_id,field_id,at desc);
create or replace function secap_private.audit_compare_value(value jsonb) returns text
language sql immutable set search_path='' as $$ select coalesce(nullif(nullif(value #>> '{}',''),'—'),'') $$;
revoke all on function secap_private.audit_compare_value(jsonb) from public,anon,authenticated;
create or replace function secap_private.link_audit_batch(log_id text) returns void
language plpgsql security definer set search_path='' as $$
declare logrow record; change record; matched uuid; actor_id uuid;
begin
 select * into logrow from public.secap_audit_legacy l where l.id=log_id;
 if not found or coalesce(logrow.entry->>'action','') not like 'Edição em lote de obras%' or jsonb_typeof(logrow.entry->'details'->'changes') is distinct from 'array' then return;end if;
 if coalesce(logrow.entry->>'user','') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then actor_id:=(logrow.entry->>'user')::uuid;end if;
 for change in select value,ord-1 as idx from jsonb_array_elements(logrow.entry->'details'->'changes') with ordinality changes(value,ord) loop
  matched:=null;
  select e.id into matched from public.secap_audit_events e
   where e.project_id=logrow.entry->>'project' and e.record_id=change.value->>'recordId' and e.field_id=change.value->>'fieldId'
   and secap_private.audit_compare_value(e.before_value)=secap_private.audit_compare_value(change.value->'before')
   and secap_private.audit_compare_value(e.after_value)=secap_private.audit_compare_value(change.value->'after')
   and e.at<=logrow.at
   and (case when actor_id is not null then e.actor=actor_id else nullif(logrow.entry->>'who','') is not null and e.who=logrow.entry->>'who' end)
   order by e.at desc,e.id desc limit 1;
  if matched is not null then insert into secap_private.audit_batch_links values(log_id,change.idx,matched) on conflict do nothing;end if;
 end loop;
end $$;
revoke all on function secap_private.link_audit_batch(text) from public,anon,authenticated;
create or replace function secap_private.capture_batch_links() returns trigger
language plpgsql security definer set search_path='' as $$ begin perform secap_private.link_audit_batch(new.id);return new;end $$;
revoke all on function secap_private.capture_batch_links() from public,anon,authenticated;
drop trigger if exists secap_link_audit_batch on public.secap_audit_legacy;
create trigger secap_link_audit_batch after insert on public.secap_audit_legacy for each row execute function secap_private.capture_batch_links();
do $$ declare row record;begin for row in select id from public.secap_audit_legacy order by at,id loop perform secap_private.link_audit_batch(row.id);end loop;end $$;
create or replace function secap_private.audit_visible_legacy(log_id text, entry jsonb) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare remaining jsonb;
begin
 if coalesce(entry->>'action','') not like 'Edição em lote de obras%' or jsonb_typeof(entry->'details'->'changes') is distinct from 'array' then return entry;end if;
 if not exists(select 1 from secap_private.audit_batch_links b where b.log_id=audit_visible_legacy.log_id) then return entry;end if;
 select coalesce(jsonb_agg(ch.value order by ch.ord),'[]'::jsonb) into remaining from jsonb_array_elements(entry->'details'->'changes') with ordinality ch(value,ord)
 where not exists(select 1 from secap_private.audit_batch_links b where b.log_id=audit_visible_legacy.log_id and b.change_index=ch.ord-1);
 if jsonb_array_length(remaining)=0 then return null;end if;
 return jsonb_set(entry,'{details,changes}',remaining);
end $$;
revoke all on function secap_private.audit_visible_legacy(text,jsonb) from public,anon,authenticated;
create or replace function secap_private.audit_batch_context(event_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select coalesce((select jsonb_build_object('details',jsonb_build_object('reason',l.entry->'details'->'reason','checklist',l.entry->'details'->'checklist'))
 from secap_private.audit_batch_links b join public.secap_audit_legacy l on l.id=b.log_id where b.event_id=audit_batch_context.event_id order by l.at desc,l.id desc limit 1),'{}'::jsonb)
$$;
revoke all on function secap_private.audit_batch_context(uuid) from public,anon,authenticated;
create or replace function public.secap_audit_page_scoped(
 p_view text default 'recent', p_start date default null, p_end date default null,
 p_before_at timestamptz default null, p_before_id text default null, p_archive_end date default null, p_scope text default 'projects'
) returns jsonb language plpgsql security definer set search_path='' as $$
declare first_day date; last_day date; cutoff date; lower_at timestamptz; upper_at timestamptz;
 selected_lower timestamptz; selected_upper timestamptz; available_start timestamptz; available_end timestamptz;
 page_rows jsonb; has_more boolean; tail jsonb;
begin
 if auth.uid() is null or not coalesce(public.is_admin(),false) then raise exception 'Auditoria restrita aos administradores.' using errcode='42501';end if;
 if p_scope is null or p_scope not in ('projects','bi') then raise exception 'Seção inválida.';end if;
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
  select min(at) as stamp from public.secap_audit_events where p_scope='projects' and at>=lower_at and at<upper_at union all
  select max(at) from public.secap_audit_events where p_scope='projects' and at>=lower_at and at<upper_at union all
  select min(at) from public.secap_audit_legacy where secap_private.audit_visible_legacy(id,entry) is not null and secap_private.audit_is_bi(entry)=(p_scope='bi') and at>=lower_at and at<upper_at union all
  select max(at) from public.secap_audit_legacy where secap_private.audit_visible_legacy(id,entry) is not null and secap_private.audit_is_bi(entry)=(p_scope='bi') and at>=lower_at and at<upper_at
 ) bounds;
 with candidates as (
  (select e.at,'server:'||e.id::text as sort_id,jsonb_build_object('id','server:'||e.id::text,'eventId',e.id,'at',e.at,'who',case when position('@' in e.who)>0 or btrim(e.who) in ('','Nome não informado','Usuário não informado') then secap_private.audit_actor_name(e.actor,e.who) else e.who end,'action',e.action,
   'project',e.project_id,'projectName',e.project_name,'recordId',e.record_id,'recordName',e.record_name,'field',e.field_name,'fieldId',e.field_id,
   'before',e.before_value,'after',e.after_value,'recoveredFrom',e.recovered_from,
   'recovered',exists(select 1 from public.secap_audit_events r where r.recovered_from=e.id),
   'recoverable',not exists(select 1 from public.secap_audit_events r where r.recovered_from=e.id)) || secap_private.audit_batch_context(e.id) as entry
   from public.secap_audit_events e where p_scope='projects' and e.at>=selected_lower and e.at<selected_upper
   and (p_before_at is null or (e.at,'server:'||e.id::text)<(p_before_at,p_before_id)) order by e.at desc,e.id desc limit 51)
  union all
  (select l.at,'legacy:'||l.id,secap_private.audit_visible_legacy(l.id,l.entry) || jsonb_build_object('id','legacy:'||l.id,'at',l.at,'recoverable',false,'eventId',null,'who',secap_private.audit_entry_name(l.entry)) from public.secap_audit_legacy l
   where secap_private.audit_visible_legacy(l.id,l.entry) is not null and secap_private.audit_is_bi(l.entry)=(p_scope='bi') and l.at>=selected_lower and l.at<selected_upper
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
    where exists(select 1 from public.secap_audit_events e where p_scope='projects' and e.at>=(d at time zone 'America/Sao_Paulo') and e.at<((d+interval '1 day') at time zone 'America/Sao_Paulo'))
       or exists(select 1 from public.secap_audit_legacy l where secap_private.audit_visible_legacy(l.id,l.entry) is not null and secap_private.audit_is_bi(l.entry)=(p_scope='bi') and l.at>=(d at time zone 'America/Sao_Paulo') and l.at<((d+interval '1 day') at time zone 'America/Sao_Paulo'))));
end $$;
revoke all on function public.secap_audit_page_scoped(text,date,date,timestamptz,text,date,text) from public,anon;
grant execute on function public.secap_audit_page_scoped(text,date,date,timestamptz,text,date,text) to authenticated;
notify pgrst, 'reload schema';
commit;
select 'Auditoria unificada com sucesso' as resultado;
