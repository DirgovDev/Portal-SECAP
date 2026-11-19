-- Limita leitura às obras atribuídas; campos continuam visíveis e a edição continua granular.
begin;
create or replace function secap_private.obra_allowed(o public.obras,editing boolean default false) returns boolean language plpgsql stable security definer set search_path='' as $$
declare ids jsonb;
begin
 if not secap_private.project_allowed(o.project_id,editing) then return false;end if;
 if public.is_admin() then return true;end if;
 select s.body->'projectWorkAccess'->auth.uid()::text->o.project_id into ids from public.app_state s where s.id=1;
 if ids is null or jsonb_typeof(ids)<>'array' then return false;end if;
 return exists(select 1 from jsonb_array_elements_text(ids) id where id=o.id);
end $$;
revoke all on function secap_private.obra_allowed(public.obras,boolean) from public,anon;
grant execute on function secap_private.obra_allowed(public.obras,boolean) to authenticated;
notify pgrst,'reload schema';
commit;
select 'Acesso às obras e verificação corrigidos com sucesso' as resultado;
