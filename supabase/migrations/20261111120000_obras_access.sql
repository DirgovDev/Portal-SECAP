-- SECAP: permissão por usuário nas obras dos projetos — "visualizar" (somente leitura) ou "editar".
-- O administrador do sistema sempre pode editar. Esta migration:
--   1) cria profiles.obras_access;
--   2) expõe a permissão na listagem de cadastros e cria a função que o administrador usa para alterá-la;
--   3) trava no banco a gravação de projetos/termos por quem é somente visualização.

-- 1) Coluna. Usuários já aprovados antes desta migration continuam podendo editar (comportamento atual);
--    novas aprovações começam como "visualizar" e o administrador libera a edição quando quiser.
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'obras_access'
  ) then
    alter table public.profiles add column obras_access text not null default 'visualizar';
    update public.profiles set obras_access = 'editar' where role = 'usuario';
  end if;
end $$;

alter table public.profiles drop constraint if exists profiles_obras_access_check;
alter table public.profiles
  add constraint profiles_obras_access_check
  check (obras_access in ('visualizar', 'editar'));

-- 2) Quem pode alterar obras (administrador ou usuário aprovado com permissão de edição).
create or replace function public.can_edit_obras()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and (p.role = 'administrador' or (p.role = 'usuario' and p.obras_access = 'editar'))
  );
$$;
revoke all on function public.can_edit_obras() from public, anon;
grant execute on function public.can_edit_obras() to authenticated;

-- 3) Listagem de cadastros agora traz o papel da conta e a permissão nas obras.
drop function if exists public.admin_list_account_requests();
create function public.admin_list_account_requests()
returns table (
  id bigint,
  name text,
  email text,
  job_title text,
  created_at timestamptz,
  status text,
  profile_role text,
  obras_access text
)
language plpgsql
stable
security definer
set search_path = public, auth
as $$
begin
  if auth.uid() is null or not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'administrador'
  ) then
    raise exception 'Acesso restrito ao administrador.' using errcode = '42501';
  end if;

  return query
    select r.id, r.name, r.email, r.job_title, r.created_at, r.status,
           pr.role, pr.obras_access
    from public.account_requests r
    left join public.profiles pr on lower(pr.email) = lower(r.email)
    order by r.created_at desc;
end;
$$;
revoke all on function public.admin_list_account_requests() from public, anon;
grant execute on function public.admin_list_account_requests() to authenticated;

-- 4) Alterar a permissão de um usuário aprovado (somente administrador).
create or replace function public.admin_set_obras_access(
  request_id bigint,
  access text
)
returns boolean
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  request_email text;
begin
  if auth.uid() is null or not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'administrador'
  ) then
    raise exception 'Acesso restrito ao administrador.' using errcode = '42501';
  end if;

  if request_id is null or request_id < 1
     or access is null or access not in ('visualizar', 'editar') then
    raise exception 'Solicitação ou permissão inválida.' using errcode = '22023';
  end if;

  select r.email into request_email
    from public.account_requests r
   where r.id = request_id and r.status = 'Aprovada';
  if not found then
    return false;
  end if;

  -- Só contas de usuário aprovado; administrador nunca é alterado por aqui.
  update public.profiles
     set obras_access = access
   where lower(email) = lower(request_email)
     and role = 'usuario';

  return found;
end;
$$;
revoke all on function public.admin_set_obras_access(bigint, text) from public, anon;
grant execute on function public.admin_set_obras_access(bigint, text) to authenticated;

-- 5) Trava no servidor: quem é somente visualização nunca altera projetos (obras) nem termos,
--    mesmo que adultere o navegador. Notas, agenda e registros continuam funcionando.
--    Chamadas sem usuário (migrations, service role, scripts de importação) não são afetadas.
create or replace function public.guard_obras_write()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if auth.uid() is not null and not public.can_edit_obras() then
    new.body := jsonb_set(
      jsonb_set(new.body, '{projects}', coalesce(old.body -> 'projects', '[]'::jsonb)),
      '{terms}',
      coalesce(old.body -> 'terms', '[]'::jsonb)
    );
  end if;
  return new;
end;
$$;
revoke all on function public.guard_obras_write() from public, anon, authenticated;

drop trigger if exists app_state_guard_obras on public.app_state;
create trigger app_state_guard_obras
  before update on public.app_state
  for each row execute function public.guard_obras_write();

notify pgrst, 'reload schema';
