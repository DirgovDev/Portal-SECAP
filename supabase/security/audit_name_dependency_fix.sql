-- Correção da dependência de identificação do responsável. Não remove registros.
begin;
create schema if not exists secap_private;
create or replace function secap_private.audit_actor_name(actor_id uuid, actor_email text default null) returns text
language sql stable security definer set search_path='' as $$
 select coalesce(
  (select nullif(btrim(p.name),'') from public.profiles p where (p.id=actor_id or (actor_id is null and lower(p.email)=lower(actor_email))) and position('@' in p.name)=0),
  (select nullif(btrim(r.name),'') from public.account_requests r where lower(r.email)=lower(coalesce((select p.email from public.profiles p where p.id=actor_id),case when position('@' in actor_email)>0 then actor_email end)) and position('@' in r.name)=0 order by r.created_at desc limit 1),
  (select coalesce(nullif(btrim(u.raw_user_meta_data->>'name'),''),nullif(btrim(u.raw_user_meta_data->>'full_name'),'')) from auth.users u where u.id=actor_id),
  'Nome não informado');
$$;
revoke all on function secap_private.audit_actor_name(uuid,text) from public,anon,authenticated;

-- Resolve somente identificadores de autoria existentes, sem adivinhar usuários.
create or replace function secap_private.audit_entry_name(entry jsonb) returns text
language plpgsql stable security definer set search_path='' as $$
declare actor_id uuid; stored_name text; actor_email text; resolved text;
begin
 stored_name:=btrim(coalesce(entry->>'who',''));
 if stored_name<>'' and stored_name not in ('Nome não informado','Usuário não informado') and position('@' in stored_name)=0 then return stored_name;end if;
 if coalesce(entry->>'user','') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then actor_id:=(entry->>'user')::uuid;end if;
 actor_email:=case when position('@' in stored_name)>0 then stored_name when position('@' in coalesce(entry->>'email',''))>0 then entry->>'email' end;
 resolved:=secap_private.audit_actor_name(actor_id,actor_email);
 return resolved;
end $$;
revoke all on function secap_private.audit_entry_name(jsonb) from public,anon,authenticated;

notify pgrst, 'reload schema';
commit;
select case when to_regprocedure('secap_private.audit_actor_name(uuid,text)') is not null and to_regprocedure('secap_private.audit_entry_name(jsonb)') is not null then 'Dependências da auditoria corrigidas com sucesso' else 'Falha na verificação das dependências' end as resultado;
