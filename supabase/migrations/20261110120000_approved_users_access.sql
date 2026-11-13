-- SECAP: usuário aprovado passa a ter acesso a todo o portal, exceto à aba Administração.
-- O administrador continua sendo o único que lê/decide cadastros, faz backup e restaura dados.

-- 1) Novos papéis: 'usuario' (aprovado) e 'recusado'.
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles
  add constraint profiles_role_check
  check (role in ('administrador', 'usuario', 'pendente', 'recusado'));

-- 2) Quem pode usar o portal (administrador ou usuário aprovado).
create or replace function public.is_member()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role in ('administrador', 'usuario')
  );
$$;
revoke all on function public.is_member() from public;
grant execute on function public.is_member() to authenticated;

-- 3) Aprovar/recusar atualiza também o papel da conta (nunca mexe em administrador).
create or replace function public.admin_update_account_request(
  request_id bigint,
  decision text
)
returns boolean
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  current_status text;
  request_email text;
begin
  if auth.uid() is null or not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'administrador'
  ) then
    raise exception 'Acesso restrito ao administrador.' using errcode = '42501';
  end if;

  if request_id is null or request_id < 1
     or decision is null or decision not in ('approve', 'reject') then
    raise exception 'Solicitação ou ação inválida.' using errcode = '22023';
  end if;

  select r.status, r.email
    into current_status, request_email
    from public.account_requests r
   where r.id = request_id
   for update;

  if not found or current_status <> 'Pendente' then
    return false;
  end if;

  update public.account_requests
     set status = case when decision = 'approve' then 'Aprovada' else 'Recusada' end
   where id = request_id;

  update public.profiles
     set role = case when decision = 'approve' then 'usuario' else 'recusado' end
   where lower(email) = lower(request_email)
     and role = 'pendente';

  return true;
end;
$$;
revoke all on function public.admin_update_account_request(bigint, text) from public, anon;
grant execute on function public.admin_update_account_request(bigint, text) to authenticated;

-- 4) Contas já decididas antes desta migration.
update public.profiles p
   set role = 'usuario'
  from public.account_requests r
 where lower(r.email) = lower(p.email) and r.status = 'Aprovada' and p.role = 'pendente';

update public.profiles p
   set role = 'recusado'
  from public.account_requests r
 where lower(r.email) = lower(p.email) and r.status = 'Recusada' and p.role = 'pendente';

-- 5) Dados do portal: administrador e usuário aprovado (a aba Administração segue só do administrador).
drop policy if exists app_state_admin_read on public.app_state;
drop policy if exists app_state_admin_insert on public.app_state;
drop policy if exists app_state_admin_update on public.app_state;
drop policy if exists app_state_member_read on public.app_state;
drop policy if exists app_state_member_insert on public.app_state;
drop policy if exists app_state_member_update on public.app_state;

create policy app_state_member_read on public.app_state
  for select to authenticated using (public.is_member());
create policy app_state_member_insert on public.app_state
  for insert to authenticated with check (public.is_member());
create policy app_state_member_update on public.app_state
  for update to authenticated using (public.is_member()) with check (public.is_member());

-- Agenda: continua privada de cada pessoa (owner = auth.uid()).
drop policy if exists calendar_admin_all on public.calendar_items;
drop policy if exists calendar_member_all on public.calendar_items;
create policy calendar_member_all on public.calendar_items
  for all to authenticated
  using (owner = auth.uid() and public.is_member())
  with check (owner = auth.uid() and public.is_member());

notify pgrst, 'reload schema';
