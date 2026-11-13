drop policy if exists account_requests_admin_update on public.account_requests;
create policy account_requests_admin_update on public.account_requests
  for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

grant update on public.account_requests to authenticated;
