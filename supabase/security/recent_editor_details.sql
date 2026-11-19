-- SECAP · Visão geral do administrador: detalhe de "Quem editou recentemente".
-- 1) secap_recent_editors passa a devolver também o identificador do usuário ("actor").
-- 2) secap_recent_editor_changes devolve o que um usuário alterou em uma obra no período
--    (campo, valor anterior, valor novo, data/hora e justificativa registrada).
-- Somente administradores. Reaplicável; não altera dados.
begin;

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
          'actor', e.actor,
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

create or replace function public.secap_recent_editor_changes(p_actor uuid, p_record text, p_days integer default 30)
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
    select jsonb_agg(c.item order by c.at desc, c.id desc)
    from (
      select e.at, e.id,
        jsonb_build_object(
          'id', e.id,
          'at', e.at,
          'who', e.who,
          'action', e.action,
          'fieldId', e.field_id,
          'field', e.field_name,
          'before', e.before_value,
          'after', e.after_value,
          'beforePresent', e.before_present,
          'afterPresent', e.after_present,
          'recordName', e.record_name,
          'projectName', e.project_name,
          'reason', nullif(secap_private.audit_batch_context(e.id)->'details'->>'reason', '')
        ) as item
      from public.secap_audit_events e
      where e.actor = p_actor and e.record_id = p_record and e.at >= since
      order by e.at desc, e.id desc
      limit 200
    ) c
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.secap_recent_editor_changes(uuid, text, integer) from public, anon;
grant execute on function public.secap_recent_editor_changes(uuid, text, integer) to authenticated;

notify pgrst, 'reload schema';
commit;
select 'Detalhe de quem editou recentemente instalado com sucesso' as resultado;
