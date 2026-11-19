-- Sincronia bidirecional com a planilha do Google (obras_prioritarias).
--
-- Cria a função usada pelo servidor do portal (server.py / sheet_sync.py) para gravar
-- no banco as alterações vindas da planilha. Só a chave service_role (servidor) pode
-- executá-la; usuários do portal não têm acesso.
--
-- As alterações vindas da planilha:
--   * aparecem na Auditoria com o autor "Planilha Google (sincronização)";
--   * não exigem "responsável obrigatório" (a planilha não tem conta de usuário).
--
-- Reaplicável. Não altera obras existentes ao ser executado.
begin;

-- 1) Auditoria: autor legível quando a alteração vem da sincronia (sem usuário conectado).
do $$
declare def text; line text := 'select secap_private.audit_actor_name(auth.uid()) into actor_name;';
begin
  def := pg_get_functiondef('secap_private.capture_obra_audit()'::regprocedure);
  if position('secap_sheet_actor' in def) = 0 then
    if position(line in def) = 0 then
      raise exception 'Versão inesperada de secap_private.capture_obra_audit(); aplique audit_admin.sql antes.';
    end if;
    def := replace(def, line, line || E'\n  /*secap_sheet_actor*/ if auth.uid() is null and nullif(current_setting(''secap.actor_label'', true), '''') is not null then actor_name := current_setting(''secap.actor_label'', true); end if;');
    execute def;
  end if;
end $$;

-- 2) Responsável obrigatório: liberado apenas para a sincronia do servidor (sem usuário).
do $$
declare def text; marker text := 'if public.is_admin() and coalesce(current_setting(''secap.responsible_sync'',true),'''')=''true'' then return new;end if;';
begin
  def := pg_get_functiondef('secap_private.require_work_responsible()'::regprocedure);
  if position('secap.sheet_sync' in def) = 0 then
    if position(marker in def) = 0 then
      raise exception 'Versão inesperada de secap_private.require_work_responsible(); aplique work_responsibles_sync.sql antes.';
    end if;
    def := replace(def, marker, marker || E'\n if auth.uid() is null and coalesce(current_setting(''secap.sheet_sync'',true),'''')=''true'' then return new;end if;');
    execute def;
  end if;
end $$;

-- 3) Aplicação das mudanças vindas da planilha.
-- p_updates: [{"id": "...", "columns": {"status": "..."}, "dados": {"campo": valor}}]
-- p_inserts: [{"id": "...", "nome": "...", "columns": {...}, "dados": {...}}]
create or replace function public.secap_sheet_sync_apply(p_project text, p_updates jsonb, p_inserts jsonb, p_sheet_name text default 'Planilha Google')
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  item jsonb; cols jsonb; k text; updated int := 0; inserted int := 0;
  allowed_cols text[] := array['nome','status','valor','executado','prazo','responsavel','progresso','proxima','orgao'];
begin
  if coalesce(auth.role(),'') <> 'service_role' then
    raise exception 'Acesso restrito ao servidor do portal.' using errcode='42501';
  end if;
  if not exists(select 1 from public.app_state s cross join lateral jsonb_array_elements(s.body->'projects') p where s.id=1 and p->>'id'=p_project) then
    raise exception 'Projeto não encontrado.';
  end if;
  perform set_config('secap.sheet_sync','true',true);
  perform set_config('secap.actor_label','Planilha Google (sincronização)',true);
  perform set_config('secap.change_reason','Sincronização com a planilha Google',true);

  for item in select * from jsonb_array_elements(coalesce(p_updates,'[]')) loop
    cols := coalesce(item->'columns','{}');
    for k in select jsonb_object_keys(cols) loop
      if not k = any(allowed_cols) then raise exception 'Coluna inválida: %', k; end if;
    end loop;
    update public.obras o set
      nome        = case when cols ? 'nome' then coalesce(cols->>'nome','') else o.nome end,
      status      = case when cols ? 'status' then cols->>'status' else o.status end,
      valor       = case when cols ? 'valor' then (cols->>'valor')::numeric else o.valor end,
      executado   = case when cols ? 'executado' then (cols->>'executado')::numeric else o.executado end,
      prazo       = case when cols ? 'prazo' then (cols->>'prazo')::date else o.prazo end,
      responsavel = case when cols ? 'responsavel' then coalesce(cols->>'responsavel','') else o.responsavel end,
      progresso   = case when cols ? 'progresso' then (cols->>'progresso')::numeric else o.progresso end,
      proxima     = case when cols ? 'proxima' then coalesce(cols->>'proxima','') else o.proxima end,
      orgao       = case when cols ? 'orgao' then coalesce(cols->>'orgao','') else o.orgao end,
      dados       = coalesce(o.dados,'{}') || coalesce(item->'dados','{}'),
      updated_at  = now()
    where o.id = item->>'id' and o.project_id = p_project;
    if found then updated := updated + 1; end if;
  end loop;

  for item in select * from jsonb_array_elements(coalesce(p_inserts,'[]')) loop
    cols := coalesce(item->'columns','{}');
    if coalesce(btrim(cols->>'nome'),'') = '' then continue; end if;
    insert into public.obras(id, project_id, nome, status, valor, executado, prazo, responsavel, progresso, proxima, orgao, dados, nome_planilha)
    values (item->>'id', p_project, cols->>'nome', coalesce(cols->>'status','Planejamento'),
            (cols->>'valor')::numeric, (cols->>'executado')::numeric, (cols->>'prazo')::date,
            coalesce(cols->>'responsavel',''), (cols->>'progresso')::numeric, coalesce(cols->>'proxima',''),
            coalesce(cols->>'orgao',''), coalesce(item->'dados','{}'), coalesce(p_sheet_name,''))
    on conflict (id) do nothing;
    if found then inserted := inserted + 1; end if;
  end loop;

  return jsonb_build_object('updated', updated, 'inserted', inserted);
end $$;
revoke all on function public.secap_sheet_sync_apply(text,jsonb,jsonb,text) from public, anon, authenticated;
grant execute on function public.secap_sheet_sync_apply(text,jsonb,jsonb,text) to service_role;

-- O servidor lê o projeto e as obras pela API com a chave service_role. No Supabase em
-- nuvem as tabelas novas não dão leitura a esse papel automaticamente: concede só leitura.
grant usage on schema public to service_role;
grant select on public.app_state, public.obras to service_role;

notify pgrst,'reload schema';
commit;
select 'Sincronia com a planilha Google preparada com sucesso' as resultado;
