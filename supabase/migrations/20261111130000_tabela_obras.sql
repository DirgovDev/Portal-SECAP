-- SECAP: Tabela dedicada para armazenamento de obras no Supabase.
-- Move as obras de cada projeto de dentro do JSON 'app_state.body' para a tabela relacional 'public.obras'.

-- 1) Criação da tabela de obras
create table if not exists public.obras (
  id text primary key,
  project_id text not null,
  nome text not null default '',
  status text not null default 'Planejamento',
  valor numeric(15, 2),
  executado numeric(15, 2),
  prazo date,
  responsavel text not null default '',
  progresso numeric(5, 2) default 0,
  proxima text not null default '',
  orgao text not null default '',
  dados jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Índices para performance em filtros e ordenações
create index if not exists obras_project_id_idx on public.obras (project_id);
create index if not exists obras_status_idx on public.obras (status);
create index if not exists obras_responsavel_idx on public.obras (responsavel);

-- 2) Segurança RLS (Row Level Security)
alter table public.obras enable row level security;

-- Leitura: administradores e usuários aprovados
drop policy if exists obras_select on public.obras;
create policy obras_select on public.obras
  for select to authenticated
  using (exists (
    select 1 from public.profiles
    where id = auth.uid() and role in ('administrador', 'usuario')
  ));

-- Escrita (criação, edição e exclusão): somente quem tem permissão can_edit_obras()
drop policy if exists obras_insert on public.obras;
create policy obras_insert on public.obras
  for insert to authenticated
  with check (public.can_edit_obras());

drop policy if exists obras_update on public.obras;
create policy obras_update on public.obras
  for update to authenticated
  using (public.can_edit_obras())
  with check (public.can_edit_obras());

drop policy if exists obras_delete on public.obras;
create policy obras_delete on public.obras
  for delete to authenticated
  using (public.can_edit_obras());

-- Permissões na tabela
revoke all on public.obras from anon, public;
grant select, insert, update, delete on public.obras to authenticated;

-- 3) Migração de dados legados do JSON 'app_state.body' para 'public.obras'
do $$
declare
  proj jsonb;
  rec jsonb;
  app_body jsonb;
  v_valor numeric;
  v_executado numeric;
  v_progresso numeric;
  v_prazo date;
  v_dados jsonb;
  standard_keys text[] := array['id', 'project_id', 'nome', 'status', 'valor', 'executado', 'prazo', 'responsavel', 'progresso', 'proxima', 'orgao', 'project'];
begin
  select body into app_body from public.app_state where id = 1;
  if app_body is not null and app_body ? 'projects' then
    for proj in select * from jsonb_array_elements(app_body->'projects')
    loop
      if proj ? 'records' and jsonb_typeof(proj->'records') = 'array' then
        for rec in select * from jsonb_array_elements(proj->'records')
        loop
          if rec ? 'id' and coalesce(rec->>'id', '') <> '' then
            -- Tratamento de valor numérico
            v_valor := null;
            if rec ? 'valor' and coalesce(rec->>'valor', '') <> '' then
              begin
                v_valor := (rec->>'valor')::numeric;
              exception when others then
                v_valor := null;
              end;
            end if;

            -- Tratamento de valor executado
            v_executado := null;
            if rec ? 'executado' and coalesce(rec->>'executado', '') <> '' then
              begin
                v_executado := (rec->>'executado')::numeric;
              exception when others then
                v_executado := null;
              end;
            end if;

            -- Tratamento de progresso
            v_progresso := 0;
            if rec ? 'progresso' and coalesce(rec->>'progresso', '') <> '' then
              begin
                v_progresso := (rec->>'progresso')::numeric;
              exception when others then
                v_progresso := 0;
              end;
            end if;

            -- Tratamento de data de prazo
            v_prazo := null;
            if rec ? 'prazo' and (rec->>'prazo') ~ '^\d{4}-\d{2}-\d{2}$' then
              begin
                v_prazo := (rec->>'prazo')::date;
              exception when others then
                v_prazo := null;
              end;
            end if;

            -- Separa dados customizados (removendo as chaves padronizadas)
            v_dados := rec - standard_keys;

            -- Inserção na tabela dedicada de obras
            insert into public.obras (
              id,
              project_id,
              nome,
              status,
              valor,
              executado,
              prazo,
              responsavel,
              progresso,
              proxima,
              orgao,
              dados
            ) values (
              rec->>'id',
              coalesce(proj->>'id', ''),
              coalesce(rec->>'nome', ''),
              case 
                when rec->>'status' in ('Planejamento', 'Em andamento', 'Em atenção', 'Concluído') then rec->>'status'
                else coalesce(rec->>'status', 'Planejamento')
              end,
              v_valor,
              v_executado,
              v_prazo,
              coalesce(rec->>'responsavel', ''),
              v_progresso,
              coalesce(rec->>'proxima', ''),
              coalesce(rec->>'orgao', ''),
              coalesce(v_dados, '{}'::jsonb)
            )
            on conflict (id) do update set
              project_id = excluded.project_id,
              nome = excluded.nome,
              status = excluded.status,
              valor = excluded.valor,
              executado = excluded.executado,
              prazo = excluded.prazo,
              responsavel = excluded.responsavel,
              progresso = excluded.progresso,
              proxima = excluded.proxima,
              orgao = excluded.orgao,
              dados = excluded.dados,
              updated_at = now();
          end if;
        end loop;
      end if;
    end loop;

    -- Limpa 'records' de dentro de app_state.body->'projects' para armazenar apenas na tabela de obras
    update public.app_state
    set body = (
      select jsonb_set(
        app_body,
        '{projects}',
        coalesce(
          (
            select jsonb_agg(p - 'records' || '{"records": []}'::jsonb)
            from jsonb_array_elements(app_body->'projects') as p
          ),
          '[]'::jsonb
        )
      )
    )
    where id = 1;
  end if;
end $$;

notify pgrst, 'reload schema';
