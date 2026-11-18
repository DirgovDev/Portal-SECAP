-- SECAP: endurecimento de RLS e privilégios.
--
-- O RLS já protegia as linhas, mas os privilégios padrão do Supabase davam a
-- anon/authenticated acesso total (inclusive TRUNCATE, que o RLS NÃO bloqueia)
-- a todas as tabelas. Esta migração deixa cada papel só com o que o portal usa:
--
--   anon (sem login) ...... nenhuma tabela; só admin_exists() e email_is_admin(),
--                            usadas nas telas de entrada e cadastro.
--   authenticated ......... só os comandos que alguma política permite; as linhas
--                            continuam filtradas pelo RLS e pelas funções seguras.
--
-- Idempotente: pode ser executada de novo sem efeito colateral.

begin;

-- 1) Toda tabela do schema public com RLS ligado (rede de segurança para tabelas futuras
--    criadas antes desta migração).
do $$
declare t record;
begin
  for t in
    select c.relname from pg_class c
    where c.relnamespace = 'public'::regnamespace and c.relkind in ('r','p')
  loop
    execute format('alter table public.%I enable row level security', t.relname);
  end loop;
end$$;

-- 2) Tabelas: zera anon e remove de authenticated o que o RLS não controla.
do $$
declare t record;
begin
  for t in
    select c.relname from pg_class c
    where c.relnamespace = 'public'::regnamespace and c.relkind in ('r','p')
  loop
    execute format('revoke all on table public.%I from anon', t.relname);
    execute format('revoke truncate, references, trigger, maintain on table public.%I from authenticated', t.relname);
  end loop;
end$$;

-- Sequências (identity de account_requests etc.) não são usadas diretamente pelo portal.
revoke all on all sequences in schema public from anon;

-- 3) Privilégios por tabela para authenticated (as linhas continuam filtradas pelo RLS).

-- profiles: só leitura do próprio perfil (admin lê todos). Alterações via RPC seguras.
revoke insert, update, delete on public.profiles from authenticated;
grant select on public.profiles to authenticated;

-- account_requests: criadas pelo trigger handle_new_user no cadastro (auth.signUp).
-- O INSERT direto pela API permitia enviar solicitações falsas sem criar conta.
drop policy if exists account_requests_insert on public.account_requests;
revoke insert, delete on public.account_requests from authenticated;
grant select, update on public.account_requests to authenticated;

-- app_state: somente administrador (política scoped_state_admin). Membros usam
-- secap_read_state() / secap_save_project_state().
revoke delete on public.app_state from authenticated;
grant select, insert, update on public.app_state to authenticated;

-- secap_member_state: só pelas funções seguras.
revoke all on public.secap_member_state from authenticated;

-- Auditoria: somente leitura (admin), escrita só pelos triggers do servidor.
revoke insert, update, delete on public.secap_audit_events, public.secap_audit_legacy from authenticated;
grant select on public.secap_audit_events, public.secap_audit_legacy to authenticated;

-- Obras, planilhas e agenda: CRUD controlado por project_allowed() / owner.
grant select, insert, update, delete on public.obras, public.planilhas_importadas, public.calendar_items to authenticated;

-- user_custom_dashboards: cada usuário aprovado gerencia apenas os próprios painéis.
drop policy if exists "Utilizadores gerem os seus próprios painéis BI" on public.user_custom_dashboards;
drop policy if exists dashboards_owner on public.user_custom_dashboards;
create policy dashboards_owner on public.user_custom_dashboards
  for all to authenticated
  using (user_id = (select auth.uid()) and public.is_member())
  with check (user_id = (select auth.uid()) and public.is_member());
grant select, insert, update, delete on public.user_custom_dashboards to authenticated;

-- obra_section_configs: estava com RLS e nenhuma política (inacessível).
-- Leitura para usuários aprovados; escrita somente administrador.
drop policy if exists section_configs_read on public.obra_section_configs;
drop policy if exists section_configs_admin_write on public.obra_section_configs;
create policy section_configs_read on public.obra_section_configs
  for select to authenticated using (public.is_member());
create policy section_configs_admin_write on public.obra_section_configs
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
grant select, insert, update, delete on public.obra_section_configs to authenticated;

-- 4) Funções: por padrão o Postgres concede EXECUTE a PUBLIC (inclui anon).
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig from pg_proc p
    where p.pronamespace = 'public'::regnamespace
      and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
  loop
    execute format('revoke execute on function %s from public, anon', f.sig);
    execute format('grant execute on function %s to authenticated, service_role', f.sig);
  end loop;
end$$;

-- Usadas antes do login (tela de entrada / primeiro administrador / cadastro).
grant execute on function public.admin_exists() to anon;
grant execute on function public.email_is_admin(text) to anon;

-- Funções de trigger não devem ser chamadas por RPC.
revoke execute on function public.guard_obras_delete_permissions() from authenticated;
revoke execute on function public.guard_obras_field_permissions() from authenticated;
revoke execute on function public.guard_obras_write() from authenticated;
revoke execute on function public.handle_new_user() from authenticated;
revoke execute on function public.sync_planilha_after_obra_delete() from authenticated;
revoke execute on function public.validate_app_state() from authenticated;

-- 5) Tabelas/sequências criadas no futuro pelo postgres em public não ficam expostas a
--    anon automaticamente; precisam de GRANT explícito.
--    Funções novas continuam recebendo EXECUTE de PUBLIC (padrão global do Postgres,
--    que não pode ser removido por schema): faça "revoke execute ... from public, anon"
--    na migração que criar cada função nova.
alter default privileges for role postgres in schema public revoke all on tables from anon;
alter default privileges for role postgres in schema public revoke all on sequences from anon;
alter default privileges for role postgres in schema public revoke execute on functions from anon;

commit;
