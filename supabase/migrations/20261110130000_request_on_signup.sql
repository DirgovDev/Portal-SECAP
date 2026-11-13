create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  first_admin boolean;
  v_name text := left(coalesce(new.raw_user_meta_data->>'name', ''), 120);
  v_job  text := left(coalesce(new.raw_user_meta_data->>'job_title', ''), 120);
begin
  perform pg_advisory_xact_lock(714201);
  select not exists (select 1 from public.profiles where role = 'administrador')
    into first_admin;

  insert into public.profiles (id, email, role, name, job_title)
  values (new.id, coalesce(new.email, ''),
          case when first_admin then 'administrador' else 'pendente' end,
          v_name, v_job);

  -- Todo cadastro que não é o primeiro administrador vira solicitação.
  if not first_admin
     and position('@' in coalesce(new.email, '')) > 1
     and char_length(new.email) <= 254 then
    insert into public.account_requests (name, email, job_title)
    values (coalesce(nullif(v_name, ''), new.email),
            lower(new.email),
            coalesce(nullif(v_job, ''), 'Não informado'))
    on conflict do nothing;
  end if;
  return new;
end;
$$;

-- Cria a solicitação para quem já está pendente sem ter uma (o seu caso).
insert into public.account_requests (name, email, job_title)
select coalesce(nullif(p.name, ''), p.email), lower(p.email),
       coalesce(nullif(p.job_title, ''), 'Não informado')
from public.profiles p
where p.role = 'pendente' and position('@' in p.email) > 1
on conflict do nothing;