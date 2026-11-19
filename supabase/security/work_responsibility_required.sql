-- Responsável obrigatório nas próximas gravações. Não altera ou apaga obras antigas.
begin;
create schema if not exists secap_private;
create or replace function secap_private.require_work_responsible() returns trigger
language plpgsql security definer set search_path='' as $$
declare owner_key text; owner_value text; names text[];
begin
 select coalesce(nullif(p->'biMapping'->>'owner',''),'responsavel') into owner_key
 from public.app_state state cross join lateral jsonb_array_elements(coalesce(state.body->'projects','[]'::jsonb)) p
 where state.id=1 and p->>'id'=new.project_id limit 1;
 owner_key:=coalesce(owner_key,'responsavel');
 owner_value:=case when owner_key='responsavel' then new.responsavel else coalesce(new.dados->>owner_key,new.responsavel) end;
 names:=array(select btrim(name) from regexp_split_to_table(coalesce(owner_value,''),'[;\n]+') name
 where btrim(name)<>'' and lower(btrim(name)) not in ('—','-','sem responsável','sem responsavel','não informado','nao informado'));
 if coalesce(array_length(names,1),0)=0 then raise exception 'É obrigatório informar pelo menos um responsável pela obra.' using errcode='23514';end if;
 if array_length(names,1)>100 or exists(select 1 from unnest(names) name where char_length(name)>254) then raise exception 'Confira os responsáveis: até 100 nomes com até 254 caracteres cada.' using errcode='23514';end if;
 return new;
end $$;
revoke all on function secap_private.require_work_responsible() from public,anon,authenticated;
drop trigger if exists secap_work_responsible_required on public.obras;
create trigger secap_work_responsible_required before insert or update on public.obras for each row execute function secap_private.require_work_responsible();
notify pgrst, 'reload schema';
commit;
select 'Responsável obrigatório por obra ativado com sucesso' as resultado;
