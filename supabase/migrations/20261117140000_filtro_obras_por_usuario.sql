-- SECAP: filtro de obras por usuário (opcional), definido em
-- Administração > Permissões por campo.
--
-- Estrutura guardada em app_state.body (somente o administrador grava app_state):
--   rowFilters: { "<email>": { "<project_id>": { "field": "regiao", "values": ["Norte","Sul"] } } }
--
-- Sem filtro para o usuário/projeto, nada muda: ele vê todas as obras do projeto.
-- Com filtro, o RLS só deixa ler, editar ou excluir obras cujo campo tenha um dos valores
-- escolhidos (comparação sem diferenciar maiúsculas/minúsculas e espaços nas pontas).
-- Na edição o WITH CHECK impede mudar o campo filtrado para um valor fora do filtro.

create or replace function secap_private.obra_field_text(o public.obras, field text)
returns text language sql immutable set search_path = '' as $$
  select case
    when field in ('nome','status','valor','executado','prazo','responsavel','progresso','proxima','orgao')
      then to_jsonb(o) ->> field
    else o.dados ->> field
  end;
$$;

create or replace function secap_private.obra_allowed(o public.obras, editing boolean default false)
returns boolean language plpgsql stable security definer set search_path = '' as $$
declare
  member_email text;
  rule jsonb;
  current_value text;
begin
  if not secap_private.project_allowed(o.project_id, editing) then
    return false;
  end if;
  if public.is_admin() then
    return true;
  end if;

  select lower(p.email) into member_email from public.profiles p where p.id = auth.uid();
  select s.body -> 'rowFilters' -> member_email -> o.project_id into rule
    from public.app_state s where s.id = 1;

  -- Sem regra (ou regra incompleta) = sem filtro.
  if rule is null or jsonb_typeof(rule) <> 'object'
     or coalesce(rule ->> 'field', '') = ''
     or jsonb_typeof(rule -> 'values') <> 'array'
     or jsonb_array_length(rule -> 'values') = 0 then
    return true;
  end if;

  current_value := lower(btrim(coalesce(secap_private.obra_field_text(o, rule ->> 'field'), '')));
  return exists (
    select 1 from jsonb_array_elements_text(rule -> 'values') v
    where lower(btrim(v)) = current_value
  );
end;
$$;

revoke all on function secap_private.obra_field_text(public.obras, text) from public, anon;
revoke all on function secap_private.obra_allowed(public.obras, boolean) from public, anon;
grant execute on function secap_private.obra_field_text(public.obras, text) to authenticated, service_role;
grant execute on function secap_private.obra_allowed(public.obras, boolean) to authenticated, service_role;

-- Políticas de obras passam a considerar o filtro (projeto + filtro do usuário).
drop policy if exists project_read on public.obras;
drop policy if exists project_insert on public.obras;
drop policy if exists project_update on public.obras;
drop policy if exists project_delete on public.obras;

create policy project_read on public.obras
  for select to authenticated using (secap_private.obra_allowed(obras, false));
create policy project_insert on public.obras
  for insert to authenticated with check (secap_private.obra_allowed(obras, true));
create policy project_update on public.obras
  for update to authenticated
  using (secap_private.obra_allowed(obras, true))
  with check (secap_private.obra_allowed(obras, true));
create policy project_delete on public.obras
  for delete to authenticated using (secap_private.obra_allowed(obras, true));

-- O usuário recebe o próprio filtro (para a tela avisar), nunca o dos demais.
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
   'projects',coalesce((select jsonb_agg(p) from jsonb_array_elements(body_value->'projects') p where secap_private.project_allowed(p->>'id')),'[]'),
   'users','[]'::jsonb,
   'notes',coalesce(personal->'notes','[]'::jsonb),
   'terms','[]'::jsonb,
   'logs','[]'::jsonb,
   -- O usuário recebe apenas as próprias regras, nunca as permissões dos demais.
   'fieldPermissions',jsonb_build_object(member_email,coalesce(body_value->'fieldPermissions'->member_email,'{}'::jsonb)),
   'rowFilters',jsonb_build_object(member_email,coalesce(body_value->'rowFilters'->member_email,'{}'::jsonb))
 );
end$function$;
