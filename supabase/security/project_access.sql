-- Aplicar depois das migrações incluídas neste ZIP. Não altera dados de obras.
begin;
create schema if not exists secap_private;
revoke all on schema secap_private from public,anon;
grant usage on schema secap_private to authenticated;
do $$begin
 if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='profiles' and column_name='project_scope') then
  alter table public.profiles add column project_scope text not null default 'selected' check(project_scope in ('all','selected'));
  alter table public.profiles add column project_ids text[] not null default '{}';
  update public.profiles set project_scope='all' where role in ('usuario','administrador');
 end if;
end$$;
create or replace function secap_private.project_allowed(pid text, editing boolean default false)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.profiles p where p.id=auth.uid() and (p.role='administrador' or (p.role='usuario' and (p.project_scope='all' or pid=any(p.project_ids)) and (not editing or p.obras_access='editar'))));
$$;
revoke all on function secap_private.project_allowed(text,boolean) from public,anon;
grant execute on function secap_private.project_allowed(text,boolean) to authenticated;
create or replace function public.secap_project_access_list() returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not public.is_admin() then raise exception 'Acesso restrito.' using errcode='42501';end if;
 return coalesce((select jsonb_agg(jsonb_build_object('request_id',r.id,'project_scope',p.project_scope,'project_ids',p.project_ids)) from public.profiles p join public.account_requests r on lower(r.email)=lower(p.email)), '[]');
end$$;
create or replace function public.secap_set_project_access(request_id bigint, scope text, project_ids text[]) returns boolean language plpgsql security definer set search_path='' as $$
declare target_email text; valid_ids text[];
begin
 if not public.is_admin() then raise exception 'Acesso restrito.' using errcode='42501';end if;
 if scope not in ('all','selected') or scope is null or project_ids is null then raise exception 'Seleção inválida.';end if;
 select coalesce(array_agg(p->>'id'),'{}') into valid_ids from public.app_state s cross join lateral jsonb_array_elements(s.body->'projects') p where s.id=1;
 if not secap_set_project_access.project_ids <@ valid_ids then raise exception 'Um dos projetos não existe mais. Atualize a lista.';end if;
 select r.email into target_email from public.account_requests r where r.id=request_id and r.status='Aprovada';
 if not found then return false;end if;
 update public.profiles p set project_scope=scope,project_ids=case when scope='all' then '{}'::text[] else (select coalesce(array_agg(distinct x),'{}') from unnest(secap_set_project_access.project_ids) x) end where lower(p.email)=lower(target_email) and p.role='usuario';
 return found;
end$$;
create table if not exists public.secap_member_state(owner uuid primary key references auth.users(id) on delete cascade,body jsonb not null default '{}');
alter table public.secap_member_state enable row level security;
revoke all on public.secap_member_state from public,anon,authenticated;
create or replace function public.secap_read_state() returns jsonb language plpgsql security definer set search_path='' as $$
declare body_value jsonb; personal jsonb;
begin
 if not public.is_member() then raise exception 'Acesso não aprovado.' using errcode='42501';end if;
 select body into body_value from public.app_state where id=1;
 if public.is_admin() or body_value is null then return body_value;end if;
 select body into personal from public.secap_member_state where owner=auth.uid();
 return jsonb_build_object('projects',coalesce((select jsonb_agg(p) from jsonb_array_elements(body_value->'projects') p where secap_private.project_allowed(p->>'id')),'[]'), 'users','[]'::jsonb,'notes',coalesce(personal->'notes','[]'::jsonb),'terms','[]'::jsonb,'logs',coalesce(personal->'logs','[]'::jsonb));
end$$;
create or replace function public.secap_save_project_state(projects jsonb, expected_projects jsonb, personal_state jsonb default '{}') returns boolean language plpgsql security definer set search_path='' as $$
declare saved jsonb; current_visible jsonb; next_projects jsonb; item jsonb;
begin
 if not public.is_member() or public.is_admin() then raise exception 'Operação inválida.' using errcode='42501';end if;
 if jsonb_typeof(projects)<>'array' or jsonb_typeof(expected_projects)<>'array' then raise exception 'Projetos inválidos.';end if;
 select body into saved from public.app_state where id=1 for update;
 select coalesce(jsonb_agg(p),'[]') into current_visible from jsonb_array_elements(saved->'projects') p where secap_private.project_allowed(p->>'id');
 if current_visible is distinct from expected_projects then raise exception 'Os projetos ou suas permissões mudaram. Recarregue antes de salvar.' using errcode='40001';end if;
 if (select coalesce(jsonb_agg(p->>'id' order by p->>'id'),'[]') from jsonb_array_elements(projects) p) is distinct from (select coalesce(jsonb_agg(p->>'id' order by p->>'id'),'[]') from jsonb_array_elements(current_visible) p) then raise exception 'Somente administradores podem criar ou excluir pastas de projeto.' using errcode='42501';end if;
 for item in select value from jsonb_array_elements(projects) loop
  if (item - 'records') is distinct from (select p - 'records' from jsonb_array_elements(current_visible) p where p->>'id'=item->>'id') and not secap_private.project_allowed(item->>'id',true) then raise exception 'Você não pode editar este projeto.' using errcode='42501';end if;
 end loop;
 select jsonb_agg(coalesce((select n - 'records' || '{"records":[]}'::jsonb from jsonb_array_elements(projects) n where n->>'id'=p->>'id'),p)) into next_projects from jsonb_array_elements(saved->'projects') p;
 update public.app_state set body=jsonb_set(saved,'{projects}',coalesce(next_projects,'[]')),updated_at=now() where id=1;
 if jsonb_typeof(coalesce(personal_state->'notes','[]'))<>'array' or jsonb_typeof(coalesce(personal_state->'logs','[]'))<>'array' then raise exception 'Dados pessoais inválidos.';end if;
 insert into public.secap_member_state(owner,body) values(auth.uid(),jsonb_build_object('notes',coalesce(personal_state->'notes','[]'),'logs',coalesce(personal_state->'logs','[]'))) on conflict(owner) do update set body=excluded.body;
 return true;
end$$;
-- Não permitir leitura direta do documento consolidado por membros.
do $$declare p record; t text;begin
 for p in select policyname from pg_policies where schemaname='public' and tablename='app_state' loop execute format('drop policy %I on public.app_state',p.policyname);end loop;
 foreach t in array array['obras','planilhas_importadas'] loop
  for p in select policyname from pg_policies where schemaname='public' and tablename=t loop execute format('drop policy %I on public.%I',p.policyname,t);end loop;
  execute format('create policy project_read on public.%I for select to authenticated using(secap_private.project_allowed(project_id))',t);
  execute format('create policy project_insert on public.%I for insert to authenticated with check(secap_private.project_allowed(project_id,true))',t);
  execute format('create policy project_update on public.%I for update to authenticated using(secap_private.project_allowed(project_id,true)) with check(secap_private.project_allowed(project_id,true))',t);
  execute format('create policy project_delete on public.%I for delete to authenticated using(secap_private.project_allowed(project_id,true))',t);
 end loop;
end$$;
create policy scoped_state_admin on public.app_state for all to authenticated using(public.is_admin()) with check(public.is_admin());
revoke all on function public.secap_project_access_list(),public.secap_set_project_access(bigint,text,text[]),public.secap_read_state(),public.secap_save_project_state(jsonb,jsonb,jsonb) from public,anon;
grant execute on function public.secap_project_access_list(),public.secap_set_project_access(bigint,text,text[]),public.secap_read_state(),public.secap_save_project_state(jsonb,jsonb,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
