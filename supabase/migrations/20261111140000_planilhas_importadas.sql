-- SECAP: Tabela de controle de planilhas importadas e vínculo com as obras.
-- Registra cada arquivo Excel/CSV importado e rastreia na tabela 'public.obras' a planilha de origem.

-- 1) Criar tabela de planilhas importadas
create table if not exists public.planilhas_importadas (
  id text primary key,
  nome_arquivo text not null,
  project_id text not null,
  total_obras integer not null default 0,
  importado_por text not null default '',
  importado_por_id uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);

-- Índices de consulta rápida
create index if not exists planilhas_project_id_idx on public.planilhas_importadas (project_id);
create index if not exists planilhas_created_at_idx on public.planilhas_importadas (created_at desc);

-- 2) Adicionar colunas de rastreamento na tabela de obras
alter table public.obras add column if not exists nome_planilha text not null default '';
alter table public.obras add column if not exists planilha_id text references public.planilhas_importadas (id) on delete set null;

create index if not exists obras_planilha_id_idx on public.obras (planilha_id);
create index if not exists obras_nome_planilha_idx on public.obras (nome_planilha);

-- 3) Políticas RLS (Row Level Security) na tabela de planilhas
alter table public.planilhas_importadas enable row level security;

-- Leitura: administradores e usuários aprovados
drop policy if exists planilhas_select on public.planilhas_importadas;
create policy planilhas_select on public.planilhas_importadas
  for select to authenticated
  using (exists (
    select 1 from public.profiles
    where id = auth.uid() and role in ('administrador', 'usuario')
  ));

-- Gravação / Exclusão: somente quem pode editar obras
drop policy if exists planilhas_insert on public.planilhas_importadas;
create policy planilhas_insert on public.planilhas_importadas
  for insert to authenticated
  with check (public.can_edit_obras());

drop policy if exists planilhas_delete on public.planilhas_importadas;
create policy planilhas_delete on public.planilhas_importadas
  for delete to authenticated
  using (public.can_edit_obras());

revoke all on public.planilhas_importadas from anon, public;
grant select, insert, delete on public.planilhas_importadas to authenticated;

notify pgrst, 'reload schema';
