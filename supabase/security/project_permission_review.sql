-- Consulta administrativa e seleção própria do Acompanhamento.
begin;
create or replace function public.secap_admin_permission_context() returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not coalesce(public.is_admin(),false) then raise exception 'Acesso restrito.' using errcode='42501';end if;
 return jsonb_build_object('users',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'email',email,'role',role,'projectScope',project_scope,'projectIds',project_ids,'obrasAccess',obras_access) order by name,id),'[]') from public.profiles where role in ('administrador','usuario')),'works',(select coalesce(body->'projectWorkAccess','{}') from public.app_state where id=1),'fields',(select coalesce(body->'fieldPermissions','{}') from public.app_state where id=1));
end $$;
create or replace function public.secap_my_work_selection() returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not coalesce(public.is_member(),false) then raise exception 'Acesso não aprovado.' using errcode='42501';end if;
 return jsonb_build_object(auth.uid()::text,coalesce((select body->'projectWorkAccess'->auth.uid()::text from public.app_state where id=1),'{}'::jsonb));
end $$;
revoke all on function public.secap_admin_permission_context(),public.secap_my_work_selection() from public,anon;
grant execute on function public.secap_admin_permission_context(),public.secap_my_work_selection() to authenticated;
notify pgrst,'reload schema';
commit;
select 'Verificação do projeto e Acompanhamento atualizados com sucesso' as resultado;
