-- Lista e atualiza solicitações por funções administrativas controladas.
-- SECURITY DEFINER permite executar a leitura/atualização sem depender de
-- policies RLS antigas, mas cada função valida auth.uid() e o perfil admin.

create or replace function public.admin_list_account_requests()
returns table (
  id bigint,
  name text,
  email text,
  job_title text,
  created_at timestamptz,
  status text
)
language plpgsql
stable
security definer
set search_path = public, auth
as $$
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

  return query
    select r.id, r.name, r.email, r.job_title, r.created_at, r.status
    from public.account_requests r
    order by r.created_at desc;
end;
$$;

create or replace function public.admin_update_account_request(
  request_id bigint,
  decision text
)
returns boolean
language plpgsql
security definer
set search_path = public, auth
as $$
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

  if decision not in ('approve', 'reject') then
    raise exception 'Ação inválida.' using errcode = '22023';
  end if;

  update public.account_requests
     set status = case when decision = 'approve' then 'Aprovada' else 'Recusada' end
   where id = request_id
     and status = 'Pendente';

  return found;
end;
$$;

revoke all on function public.admin_list_account_requests() from public, anon;
revoke all on function public.admin_update_account_request(bigint, text) from public, anon;
grant execute on function public.admin_list_account_requests() to authenticated;
grant execute on function public.admin_update_account_request(bigint, text) to authenticated;

notify pgrst, 'reload schema';
