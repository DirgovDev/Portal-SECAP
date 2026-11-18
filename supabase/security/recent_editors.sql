-- SECAP · Visão geral do administrador: "Quem editou recentemente".
-- Agrupa a auditoria de obras (public.secap_audit_events) por usuário: última edição,
-- quantidade de campos alterados e as obras editadas (com data e hora).
-- Alterações sem usuário (actor nulo: importações/sincronizações feitas direto no banco)
-- não entram, pois não foram registradas por uma pessoa.
-- Somente administradores podem consultar.

create or replace function public.secap_recent_editors(p_days integer default 30, p_users integer default 12, p_obras integer default 8)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  since timestamptz;
begin
  if auth.uid() is null or not coalesce(public.is_admin(), false) then
    raise exception 'Consulta restrita aos administradores.' using errcode = '42501';
  end if;
  since := now() - make_interval(days => greatest(1, least(coalesce(p_days, 30), 365)));

  return coalesce((
    select jsonb_agg(u.item order by u.last_at desc)
    from (
      select
        max(e.at) as last_at,
        jsonb_build_object(
          'who', (array_agg(e.who order by e.at desc))[1],
          'lastAt', max(e.at),
          'changes', count(*),
          'obrasCount', count(distinct e.record_id),
          'obras', (
            select coalesce(jsonb_agg(o.item order by o.at desc), '[]'::jsonb)
            from (
              select
                max(x.at) as at,
                jsonb_build_object(
                  'recordId', x.record_id,
                  'recordName', (array_agg(x.record_name order by x.at desc))[1],
                  'projectId', (array_agg(x.project_id order by x.at desc))[1],
                  'projectName', (array_agg(x.project_name order by x.at desc))[1],
                  'at', max(x.at),
                  'changes', count(*)
                ) as item
              from public.secap_audit_events x
              where x.actor = e.actor and x.at >= since
              group by x.record_id
              order by max(x.at) desc
              limit greatest(1, least(coalesce(p_obras, 8), 50))
            ) o
          )
        ) as item
      from public.secap_audit_events e
      where e.actor is not null and e.at >= since
      group by e.actor
      order by max(e.at) desc
      limit greatest(1, least(coalesce(p_users, 12), 50))
    ) u
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.secap_recent_editors(integer, integer, integer) from public, anon;
grant execute on function public.secap_recent_editors(integer, integer, integer) to authenticated;
