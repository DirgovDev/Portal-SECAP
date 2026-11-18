-- SECAP: registro semanal de alterações.
--
-- 1) A auditoria do servidor passa a registrar também CRIAÇÃO e EXCLUSÃO de obras
--    (antes só registrava edição de campos). Na exclusão, os valores anteriores da obra
--    ficam guardados em before_value.
-- 2) Ações de configuração gravadas pelo portal (secap_audit_legacy) passam a guardar o
--    UUID de quem salvou (entry.actor), para agrupar por usuário com segurança.
-- 3) public.secap_weekly_log(): consulta semanal (segunda a domingo, horário de Brasília)
--    somente para administradores. As tabelas continuam somente leitura para o portal:
--    ninguém edita ou exclui registros pela API (ver 20261117130000_endurecer_rls.sql).

-- ---------------------------------------------------------------------------
-- 1) Captura de criação / edição / exclusão de obras
-- ---------------------------------------------------------------------------
create or replace function secap_private.capture_obra_audit()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  old_flat jsonb; new_flat jsonb; k text; pname text; fname text; actor_name text;
  row_ref public.obras%rowtype;
begin
  row_ref := case when tg_op = 'DELETE' then old else new end;
  select secap_private.audit_actor_name(auth.uid()) into actor_name;
  select p->>'name' into pname
    from public.app_state s cross join lateral jsonb_array_elements(s.body->'projects') p
   where s.id = 1 and p->>'id' = row_ref.project_id;

  if tg_op = 'INSERT' then
    new_flat := new.dados || (to_jsonb(new) - 'dados');
    insert into public.secap_audit_events(actor, who, project_id, project_name, record_id, record_name, field_id, field_name,
      before_value, after_value, before_present, after_present, action)
    values (auth.uid(), coalesce(actor_name, 'Sistema'), new.project_id, coalesce(pname, new.project_id), new.id, new.nome,
      '', 'Obra', null, new_flat - array['created_at','updated_at'], false, true, 'Cadastrou obra');
    return new;
  end if;

  if tg_op = 'DELETE' then
    old_flat := old.dados || (to_jsonb(old) - 'dados');
    insert into public.secap_audit_events(actor, who, project_id, project_name, record_id, record_name, field_id, field_name,
      before_value, after_value, before_present, after_present, action)
    values (auth.uid(), coalesce(actor_name, 'Sistema'), old.project_id, coalesce(pname, old.project_id), old.id, old.nome,
      '', 'Obra', old_flat - array['created_at','updated_at'], null, true, false, 'Excluiu obra');
    return old;
  end if;

  -- UPDATE: uma linha por campo alterado (comportamento original).
  old_flat := old.dados || (to_jsonb(old) - 'dados');
  new_flat := new.dados || (to_jsonb(new) - 'dados');
  for k in select jsonb_object_keys(old_flat || new_flat) loop
    if k = any(array['id','project_id','created_at','updated_at']) then continue; end if;
    if (old_flat->k) is not distinct from (new_flat->k) and (old_flat ? k) = (new_flat ? k) then continue; end if;
    select f->>'name' into fname
      from public.app_state s cross join lateral jsonb_array_elements(s.body->'projects') p
      cross join lateral jsonb_array_elements(coalesce(p->'fields','[]'::jsonb)) f
     where s.id = 1 and p->>'id' = new.project_id and f->>'id' = k limit 1;
    insert into public.secap_audit_events(actor, who, project_id, project_name, record_id, record_name, field_id, field_name,
      before_value, after_value, before_present, after_present, action, recovered_from)
    values (auth.uid(), coalesce(actor_name, 'Sistema'), new.project_id, coalesce(pname, new.project_id), new.id, new.nome, k,
      coalesce(fname, k), old_flat->k, new_flat->k, old_flat ? k, new_flat ? k,
      case when nullif(current_setting('secap.recovery_event', true), '') is null then 'Alterou campo' else 'Recuperou informação anterior' end,
      nullif(current_setting('secap.recovery_event', true), '')::uuid);
  end loop;
  return new;
end $$;

drop trigger if exists secap_capture_audit on public.obras;
create trigger secap_capture_audit
  after insert or update or delete on public.obras
  for each row execute function secap_private.capture_obra_audit();

-- ---------------------------------------------------------------------------
-- 2) Autor das ações de configuração (logs gravados pelo portal)
-- ---------------------------------------------------------------------------
drop function if exists secap_private.index_legacy_audit(jsonb, uuid);
create or replace function secap_private.index_legacy_audit(entries jsonb, owner_id uuid default null, actor_id uuid default null)
returns void language plpgsql security definer set search_path = '' as $$
declare e jsonb; stamp timestamptz; actor_name text;
begin
  if jsonb_typeof(entries) is distinct from 'array' then return; end if;
  if owner_id is not null then select secap_private.audit_actor_name(owner_id) into actor_name; end if;
  for e in select value from jsonb_array_elements(entries) loop
    begin stamp := (e->>'at')::timestamptz; exception when others then stamp := null; end;
    if stamp is null then continue; end if;
    if owner_id is not null then
      e := e || jsonb_build_object('user', owner_id, 'who', coalesce(actor_name, e->>'who', 'Usuário não informado'), 'actor', owner_id);
    elsif actor_id is not null and not (e ? 'actor') then
      e := e || jsonb_build_object('actor', actor_id);
    end if;
    -- on conflict: registros já indexados nunca são alterados.
    insert into public.secap_audit_legacy(id, at, entry)
    values (coalesce(nullif(e->>'id', ''), md5(e::text)), stamp, e) on conflict (id) do nothing;
  end loop;
end $$;
revoke all on function secap_private.index_legacy_audit(jsonb, uuid, uuid) from public, anon, authenticated;

create or replace function secap_private.capture_legacy_audit()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_table_name = 'app_state' then
    if tg_op = 'UPDATE' then perform secap_private.index_legacy_audit(old.body->'logs'); end if;
    -- Só administradores gravam app_state: quem salva é o autor das novas entradas.
    perform secap_private.index_legacy_audit(new.body->'logs', null, auth.uid());
  else
    if tg_op = 'UPDATE' then perform secap_private.index_legacy_audit(old.body->'logs', old.owner); end if;
    perform secap_private.index_legacy_audit(new.body->'logs', new.owner);
  end if;
  return new;
end $$;

-- ---------------------------------------------------------------------------
-- 3) Consulta semanal
-- ---------------------------------------------------------------------------
-- Identifica o usuário de um registro legado, sem adivinhar:
--   1. UUID gravado no registro (actor/user);
--   2. user = 'admin', existia um único administrador na data e o nome confere;
--   3. nome igual ao de um único perfil.
create or replace function secap_private.legacy_actor(entry jsonb, stamp timestamptz default null)
returns uuid language plpgsql stable security definer set search_path = '' as $$
declare v text; found_id uuid; matches int;
begin
  foreach v in array array[entry->>'actor', entry->>'user'] loop
    if coalesce(v, '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then return v::uuid; end if;
  end loop;
  if entry->>'user' = 'admin' and stamp is not null then
    select count(*), min(p.id::text)::uuid into matches, found_id
      from public.profiles p where p.role = 'administrador' and p.created_at <= stamp
       -- o nome registrado precisa ser o desse administrador ou o nome padrão "Administrador…"
       and (lower(btrim(coalesce(entry->>'who', ''))) = lower(btrim(secap_private.audit_actor_name(p.id)))
            or coalesce(entry->>'who', '') ilike 'Administrador%' or coalesce(entry->>'who', '') = '');
    if matches = 1 then return found_id; end if;
  end if;
  select count(*), min(p.id::text)::uuid into matches, found_id
    from public.profiles p
   where p.role in ('administrador','usuario')
     and lower(btrim(secap_private.audit_actor_name(p.id))) = lower(btrim(coalesce(entry->>'who', '')))
     and (entry->>'user' is distinct from 'admin' or p.role = 'administrador');
  return case when matches = 1 then found_id end;
end $$;
revoke all on function secap_private.legacy_actor(jsonb, timestamptz) from public, anon, authenticated;

create or replace function public.secap_weekly_log(p_week date default null, p_weeks integer default 4)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  tz constant text := 'America/Sao_Paulo';
  today date := (current_timestamp at time zone tz)::date;
  newest date;   -- segunda-feira da semana mais recente da página
  oldest date;   -- segunda-feira da semana mais antiga da página
  first_event timestamptz;
  result jsonb;
begin
  if auth.uid() is null or not coalesce(public.is_admin(), false) then
    raise exception 'Registro semanal restrito aos administradores.' using errcode = '42501';
  end if;
  p_weeks := least(greatest(coalesce(p_weeks, 4), 1), 12);
  newest := date_trunc('week', least(coalesce(p_week, today), today))::date;
  oldest := newest - (p_weeks - 1) * 7;

  select min(at) into first_event from (
    select min(at) at from public.secap_audit_events
    union all select min(at) from public.secap_audit_legacy) m;

  with weeks as (
    select w::date ws, (w + interval '6 days')::date we,
           (w::timestamp at time zone tz) lo, ((w + interval '7 days')::timestamp at time zone tz) hi
      from generate_series(newest::timestamp, oldest::timestamp, interval '-7 days') w
  ),
  ev as (  -- alterações de obras capturadas pelo servidor
    select w.ws, e.at, e.actor as uid, e.who, e.action, e.project_id, e.project_name, e.record_id, e.record_name,
           e.field_name, case when e.field_id = '' then null else e.before_value end as before_value,
           case when e.field_id = '' then null else e.after_value end as after_value
      from weeks w join public.secap_audit_events e on e.at >= w.lo and e.at < w.hi
  ),
  lg as (  -- configurações e demais ações registradas pelo portal
    select w.ws, l.at, secap_private.legacy_actor(l.entry, l.at) as uid, secap_private.audit_entry_name(l.entry) as who,
           l.entry->>'action' as action, coalesce(nullif(l.entry->>'where', ''), nullif(l.entry->>'projectName', ''), 'Portal') as onde,
           l.entry->>'before' as before_value, l.entry->>'after' as after_value
      from weeks w join public.secap_audit_legacy l on l.at >= w.lo and l.at < w.hi
     -- Edições de campo de obra já vêm do servidor; evita contar em dobro registros antigos sem backend.
     where not (coalesce(l.entry->>'action', '') in ('Cadastrou obra', 'Excluiu obra')
                and exists (select 1 from public.secap_audit_events x
                             where x.action = l.entry->>'action' and abs(extract(epoch from x.at - l.at)) < 120))
  ),
  -- Chave do autor: UUID quando conhecido; senão o nome registrado.
  ev_k as (select ev.*, coalesce(uid::text, 'nome:' || coalesce(nullif(btrim(who), ''), 'Sistema')) akey from ev),
  lg_k as (select lg.*, coalesce(uid::text, 'nome:' || coalesce(nullif(btrim(who), ''), 'Sistema')) akey from lg),
  actors as (
    select ws, akey, max(uid::text)::uuid uid, max(who) who
      from (select ws, akey, uid, who from ev_k union all select ws, akey, uid, who from lg_k) a group by ws, akey
  ),
  per_record as (
    select ws, akey, project_id, record_id,
           jsonb_build_object('project', max(project_name), 'recordId', record_id, 'record', max(record_name),
             'changes', jsonb_agg(jsonb_build_object('at', at, 'action', action, 'field', field_name,
                          'before', before_value, 'after', after_value) order by at)) as item,
           count(*) n, max(at) last_at
      from ev_k group by ws, akey, project_id, record_id
  ),
  per_user as (
    select a.ws, a.akey,
      jsonb_build_object(
        'userId', a.uid,
        'name', case when a.uid is not null then secap_private.audit_actor_name(a.uid) else coalesce(nullif(a.who, ''), 'Sistema') end,
        'role', (select p.role from public.profiles p where p.id = a.uid),
        'identified', a.uid is not null,
        'changes', coalesce((select sum(n) from per_record r where r.ws = a.ws and r.akey = a.akey), 0)
                 + (select count(*) from lg_k where lg_k.ws = a.ws and lg_k.akey = a.akey),
        'records', coalesce((select jsonb_agg(r.item order by r.last_at desc) from per_record r
                              where r.ws = a.ws and r.akey = a.akey), '[]'::jsonb),
        'other', coalesce((select jsonb_agg(jsonb_build_object('at', l.at, 'action', l.action, 'where', l.onde,
                              'before', l.before_value, 'after', l.after_value) order by l.at desc)
                             from lg_k l where l.ws = a.ws and l.akey = a.akey), '[]'::jsonb)
      ) as item
    from actors a
  )
  select jsonb_build_object(
    'today', today,
    'newestWeek', newest,
    'oldestWeek', oldest,
    'currentWeek', date_trunc('week', today)::date,
    'firstEventWeek', (date_trunc('week', first_event at time zone tz))::date,
    'hasOlder', first_event is not null and first_event < (oldest::timestamp at time zone tz),
    'weeks', coalesce(jsonb_agg(jsonb_build_object(
      'start', w.ws,
      'end', w.we,
      'total', coalesce((select sum((u.item->>'changes')::int) from per_user u where u.ws = w.ws), 0),
      'records', (select count(distinct (r.project_id, r.record_id)) from per_record r where r.ws = w.ws),
      'users', coalesce((select jsonb_agg(u.item order by (u.item->>'changes')::int desc, u.item->>'name')
                           from per_user u where u.ws = w.ws), '[]'::jsonb),
      -- Usuários com acesso naquela semana que não fizeram alterações.
      'inactive', coalesce((select jsonb_agg(jsonb_build_object('userId', p.id, 'name', secap_private.audit_actor_name(p.id), 'role', p.role)
                                             order by secap_private.audit_actor_name(p.id))
                              from public.profiles p
                             where p.role in ('administrador', 'usuario')
                               and p.created_at < w.hi
                               and not exists (select 1 from actors a where a.ws = w.ws and a.uid = p.id)), '[]'::jsonb)
    ) order by w.ws desc), '[]'::jsonb)
  ) into result
  from weeks w;
  return result;
end $$;

revoke all on function public.secap_weekly_log(date, integer) from public, anon;
grant execute on function public.secap_weekly_log(date, integer) to authenticated, service_role;
