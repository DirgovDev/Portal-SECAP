-- SECAP · Notificação semanal por e-mail: obras sem edição na semana.
--
-- Para cada conta de usuário vinculada a obras (Responsável Acompanhamento ou seleção
-- individual nas Permissões do projeto), lista as obras que NÃO tiveram nenhuma alteração
-- registrada na auditoria durante a semana (segunda a domingo, horário de Brasília).
-- O servidor do portal (weekly_notify.py) envia o e-mail e grava aqui o resultado:
--   * public.secap_weekly_notifications: controle por semana/conta (evita envio duplicado);
--   * public.secap_audit_legacy: registro na Auditoria ("Notificação semanal enviada").
--
-- Requer responsible_acompanhamento_access.sql (função secap_private.effective_work_map).
-- Reaplicável. Não altera obras.
begin;

create table if not exists public.secap_weekly_notifications (
  id uuid primary key default gen_random_uuid(),
  week_start date not null,
  user_id uuid not null,
  email text not null default '',
  name text not null default '',
  obras jsonb not null default '[]'::jsonb,
  status text not null check (status in ('enviado', 'teste', 'erro')),
  error text not null default '',
  origin text not null default '',
  created_at timestamptz not null default now(),
  unique (week_start, user_id)
);
alter table public.secap_weekly_notifications enable row level security;
drop policy if exists weekly_notifications_admin_read on public.secap_weekly_notifications;
create policy weekly_notifications_admin_read on public.secap_weekly_notifications
  for select to authenticated using (public.is_admin());
revoke insert, update, delete on public.secap_weekly_notifications from anon, authenticated;

-- Segunda-feira da semana (horário de Brasília) que contém a data informada.
create or replace function secap_private.week_monday(p_day date) returns date
language sql immutable set search_path = '' as $$
  select p_day - ((extract(isodow from p_day)::int) - 1)
$$;

-- Obras sem edição na semana, agrupadas por conta vinculada.
-- p_week: qualquer dia da semana desejada; nulo = semana anterior à atual.
create or replace function public.secap_weekly_notify_pending(p_week date default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  monday date; t0 timestamptz; t1 timestamptz;
begin
  if coalesce(auth.role(), '') <> 'service_role' and not coalesce(public.is_admin(), false) then
    raise exception 'Consulta restrita aos administradores.' using errcode = '42501';
  end if;
  monday := secap_private.week_monday(coalesce(p_week, (now() at time zone 'America/Sao_Paulo')::date - 7));
  t0 := monday::timestamp at time zone 'America/Sao_Paulo';
  t1 := (monday + 7)::timestamp at time zone 'America/Sao_Paulo';

  return jsonb_build_object(
    'weekStart', monday,
    'weekEnd', monday + 6,
    'accounts', coalesce((
      select jsonb_agg(acc.item order by acc.name)
      from (
        select p.name,
          jsonb_build_object(
            'userId', p.id,
            'name', coalesce(nullif(btrim(p.name), ''), p.email),
            'email', p.email,
            'obras', obras.list,
            'total', jsonb_array_length(obras.list),
            'lastStatus', n.status,
            'lastAt', n.created_at
          ) as item
        from public.profiles p
        cross join lateral (
          select coalesce(jsonb_agg(jsonb_build_object(
                   'id', o.id, 'nome', o.nome, 'codigo', o.dados->>'codigo', 'projectId', o.project_id,
                   'projectName', (select pr->>'name' from public.app_state s
                                   cross join lateral jsonb_array_elements(s.body->'projects') pr
                                   where s.id = 1 and pr->>'id' = o.project_id limit 1))
                 order by o.nome), '[]'::jsonb) as list
          from public.obras o
          where secap_private.user_has_work(p.id, o)
            and not exists (
              select 1 from public.secap_audit_events e
              where e.record_id = o.id and e.at >= t0 and e.at < t1)
        ) obras
        left join public.secap_weekly_notifications n on n.week_start = monday and n.user_id = p.id
        where p.role = 'usuario' and coalesce(p.email, '') <> ''
      ) acc
      where (acc.item->>'total')::int > 0
    ), '[]'::jsonb)
  );
end $$;
revoke all on function public.secap_weekly_notify_pending(date) from public, anon;
grant execute on function public.secap_weekly_notify_pending(date) to authenticated, service_role;

-- Grava o resultado de uma notificação (somente o servidor do portal).
create or replace function public.secap_weekly_notify_record(
  p_week date, p_user uuid, p_email text, p_name text, p_obras jsonb,
  p_status text, p_error text default '', p_origin text default 'automático')
returns boolean language plpgsql security definer set search_path = '' as $$
declare
  monday date := secap_private.week_monday(p_week);
  log_id text := gen_random_uuid()::text;
  projects text;
  action_text text;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'Acesso restrito ao servidor do portal.' using errcode = '42501';
  end if;
  if p_status not in ('enviado', 'teste', 'erro') then raise exception 'Status inválido.'; end if;

  insert into public.secap_weekly_notifications(week_start, user_id, email, name, obras, status, error, origin)
  values (monday, p_user, coalesce(p_email, ''), coalesce(p_name, ''), coalesce(p_obras, '[]'), p_status,
          coalesce(p_error, ''), coalesce(p_origin, ''))
  on conflict (week_start, user_id) do update
    set email = excluded.email, name = excluded.name, obras = excluded.obras, status = excluded.status,
        error = excluded.error, origin = excluded.origin, created_at = now();

  select string_agg(distinct x->>'projectName', ', ') into projects from jsonb_array_elements(coalesce(p_obras, '[]')) x;
  action_text := case p_status
    when 'enviado' then 'Notificação semanal enviada'
    when 'teste' then 'Notificação semanal gerada (modo teste, sem envio)'
    else 'Falha na notificação semanal' end;

  insert into public.secap_audit_legacy(id, at, entry) values (log_id, now(), jsonb_build_object(
    'id', log_id,
    'at', to_char(now() at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    'who', 'Sistema · Notificação semanal',
    'user', null, 'actor', null,
    'action', action_text,
    'where', coalesce(projects, ''),
    'field', 'E-mail',
    'before', '',
    'after', coalesce(p_email, '') || ' · ' || jsonb_array_length(coalesce(p_obras, '[]')) || ' obra(s) sem edição',
    'source', 'projects',
    'details', jsonb_build_object(
      'semana', to_char(monday, 'DD/MM/YYYY') || ' a ' || to_char(monday + 6, 'DD/MM/YYYY'),
      'conta', p_name, 'email', p_email, 'status', p_status, 'erro', coalesce(p_error, ''),
      'origem', p_origin, 'obras', coalesce(p_obras, '[]'),
      'reason', 'Obras sem edição na semana ' || to_char(monday, 'DD/MM') || ' a ' || to_char(monday + 6, 'DD/MM')
                || ': ' || coalesce((select string_agg(x->>'nome', '; ') from jsonb_array_elements(coalesce(p_obras, '[]')) x), ''))));
  return true;
end $$;
revoke all on function public.secap_weekly_notify_record(date, uuid, text, text, jsonb, text, text, text) from public, anon, authenticated;
grant execute on function public.secap_weekly_notify_record(date, uuid, text, text, jsonb, text, text, text) to service_role;

notify pgrst, 'reload schema';
commit;
select 'Notificação semanal instalada com sucesso' as resultado;
