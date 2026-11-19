-- SECAP · Sino de notificações do administrador.
-- As notificações semanais (public.secap_weekly_notifications) ficam acumuladas e
-- aparecem no sino do cabeçalho para os administradores, com contador de não lidas.
-- "Lida" é por administrador (public.secap_notification_reads).
-- Requer weekly_notify.sql. Reaplicável; não altera dados existentes.
begin;

create table if not exists public.secap_notification_reads (
  user_id uuid primary key,
  last_seen_at timestamptz not null default now()
);
alter table public.secap_notification_reads enable row level security;
revoke all on public.secap_notification_reads from anon, authenticated;

create or replace function public.secap_admin_notifications(p_limit integer default 60)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare seen timestamptz;
begin
  if auth.uid() is null or not coalesce(public.is_admin(), false) then
    raise exception 'Consulta restrita aos administradores.' using errcode = '42501';
  end if;
  select r.last_seen_at into seen from public.secap_notification_reads r where r.user_id = auth.uid();
  return jsonb_build_object(
    'lastSeen', seen,
    'unread', (select count(*) from public.secap_weekly_notifications n where seen is null or n.created_at > seen),
    'total', (select count(*) from public.secap_weekly_notifications),
    'items', coalesce((
      select jsonb_agg(x.item order by x.created_at desc)
      from (
        select n.created_at, jsonb_build_object(
          'id', n.id, 'at', n.created_at, 'weekStart', n.week_start, 'weekEnd', n.week_start + 6,
          'name', n.name, 'email', n.email, 'total', jsonb_array_length(n.obras), 'obras', n.obras,
          'status', n.status, 'error', n.error, 'origin', n.origin,
          'unread', seen is null or n.created_at > seen) as item
        from public.secap_weekly_notifications n
        order by n.created_at desc
        limit greatest(1, least(coalesce(p_limit, 60), 300))
      ) x
    ), '[]'::jsonb));
end $$;
revoke all on function public.secap_admin_notifications(integer) from public, anon;
grant execute on function public.secap_admin_notifications(integer) to authenticated;

create or replace function public.secap_admin_notifications_seen()
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or not coalesce(public.is_admin(), false) then
    raise exception 'Acesso restrito aos administradores.' using errcode = '42501';
  end if;
  insert into public.secap_notification_reads(user_id, last_seen_at) values (auth.uid(), now())
  on conflict (user_id) do update set last_seen_at = now();
  return true;
end $$;
revoke all on function public.secap_admin_notifications_seen() from public, anon;
grant execute on function public.secap_admin_notifications_seen() to authenticated;

notify pgrst, 'reload schema';
commit;
select 'Sino de notificações do administrador instalado com sucesso' as resultado;
