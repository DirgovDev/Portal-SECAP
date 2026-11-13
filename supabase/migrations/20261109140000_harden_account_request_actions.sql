-- SECAP: processamento transacional e seguro das decisões de acesso.
-- A aprovação registra a decisão da solicitação; não eleva o perfil para administrador.

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
begin
  if auth.uid() is null or not exists (
    select 1
      from public.profiles p
     where p.id = auth.uid()
       and p.role = 'administrador'
  ) then
    raise exception 'Acesso restrito ao administrador.'
      using errcode = '42501';
  end if;

  if request_id is null or request_id < 1
     or decision is null or decision not in ('approve', 'reject') then
    raise exception 'Solicitação ou ação inválida.'
      using errcode = '22023';
  end if;

  -- Bloqueia a linha para impedir duas decisões simultâneas sobre a mesma solicitação.
  select r.status
    into current_status
    from public.account_requests r
   where r.id = request_id
   for update;

  if not found then
    return false;
  end if;

  if current_status <> 'Pendente' then
    return false;
  end if;

  update public.account_requests
     set status = case
       when decision = 'approve' then 'Aprovada'
       else 'Recusada'
     end
   where id = request_id;

  return true;
end;
$$;

revoke all on function public.admin_update_account_request(bigint, text) from public, anon;
grant execute on function public.admin_update_account_request(bigint, text) to authenticated;
notify pgrst, 'reload schema';
