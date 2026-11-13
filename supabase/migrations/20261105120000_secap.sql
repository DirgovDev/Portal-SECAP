-- SECAP: autenticação, estado do portal, agenda e solicitações.
-- Execute no SQL Editor do Supabase ou com `supabase db push`.

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  role text not null default 'pendente' check (role in ('administrador', 'pendente')),
  name text not null default '',
  job_title text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.app_state (
  id integer primary key check (id = 1),
  body jsonb not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.calendar_items (
  id text primary key check (char_length(id) between 8 and 80),
  owner uuid not null references auth.users (id) on delete cascade,
  body jsonb not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.account_requests (
  id bigint generated always as identity primary key,
  name text not null check (char_length(name) between 1 and 120),
  email text not null check (position('@' in email) > 1 and char_length(email) <= 254),
  job_title text not null check (char_length(job_title) between 1 and 120),
  created_at timestamptz not null default now(),
  status text not null default 'Pendente' check (status in ('Pendente', 'Aprovada', 'Recusada'))
);

create unique index if not exists account_requests_email_key
  on public.account_requests (lower(email));
create index if not exists calendar_items_owner_idx
  on public.calendar_items (owner);
create unique index if not exists profiles_email_key
  on public.profiles (lower(email));

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'administrador'
  );
$$;

create or replace function public.admin_exists()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles where role = 'administrador'
  );
$$;

create or replace function public.email_is_admin(target text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where lower(email) = lower(target) and role = 'administrador'
  );
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  first_admin boolean;
begin
  perform pg_advisory_xact_lock(714201);
  select not exists (
    select 1 from public.profiles where role = 'administrador'
  ) into first_admin;

  insert into public.profiles (id, email, role, name, job_title)
  values (
    new.id,
    coalesce(new.email, ''),
    case when first_admin then 'administrador' else 'pendente' end,
    left(coalesce(new.raw_user_meta_data->>'name', ''), 120),
    left(coalesce(new.raw_user_meta_data->>'job_title', ''), 120)
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.validate_app_state()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  admin_count integer;
begin
  if new.body is null or jsonb_typeof(new.body) <> 'object' then
    raise exception 'Estrutura de dados inválida.';
  end if;
  if jsonb_typeof(new.body->'projects') <> 'array'
     or jsonb_typeof(new.body->'users') <> 'array'
     or jsonb_typeof(new.body->'notes') <> 'array'
     or jsonb_typeof(new.body->'terms') <> 'array'
     or jsonb_typeof(new.body->'logs') <> 'array' then
    raise exception 'Estrutura de dados inválida.';
  end if;
  select count(*) into admin_count
  from jsonb_array_elements(new.body->'users') as u
  where u->>'id' = 'admin'
    and u->>'role' = 'Administrador'
    and u->>'status' = 'Ativo';
  if admin_count <> 1 then
    raise exception 'O administrador principal deve permanecer ativo.';
  end if;
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists app_state_validate on public.app_state;
create trigger app_state_validate
  before insert or update on public.app_state
  for each row execute function public.validate_app_state();

alter table public.profiles enable row level security;
alter table public.app_state enable row level security;
alter table public.calendar_items enable row level security;
alter table public.account_requests enable row level security;

drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select to authenticated
  using (id = auth.uid() or public.is_admin());

drop policy if exists app_state_admin_read on public.app_state;
create policy app_state_admin_read on public.app_state
  for select to authenticated
  using (public.is_admin());

drop policy if exists app_state_admin_insert on public.app_state;
create policy app_state_admin_insert on public.app_state
  for insert to authenticated
  with check (public.is_admin());

drop policy if exists app_state_admin_update on public.app_state;
create policy app_state_admin_update on public.app_state
  for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists calendar_admin_all on public.calendar_items;
create policy calendar_admin_all on public.calendar_items
  for all to authenticated
  using (owner = auth.uid() and public.is_admin())
  with check (owner = auth.uid() and public.is_admin());

drop policy if exists account_requests_insert on public.account_requests;
create policy account_requests_insert on public.account_requests
  for insert to anon, authenticated
  with check (status = 'Pendente');

drop policy if exists account_requests_admin_read on public.account_requests;
create policy account_requests_admin_read on public.account_requests
  for select to authenticated
  using (public.is_admin());

revoke all on function public.is_admin() from public;
revoke all on function public.handle_new_user() from public, anon, authenticated;
revoke all on function public.validate_app_state() from public, anon, authenticated;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.admin_exists() to anon, authenticated;
grant execute on function public.email_is_admin(text) to anon, authenticated;

grant usage on schema public to anon, authenticated;
grant select on public.profiles to authenticated;
grant select, insert, update on public.app_state to authenticated;
grant select, insert, update, delete on public.calendar_items to authenticated;
grant insert on public.account_requests to anon, authenticated;
grant select on public.account_requests to authenticated;
grant usage, select on all sequences in schema public to anon, authenticated;
