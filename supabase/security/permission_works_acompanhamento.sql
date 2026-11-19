-- Permissões do projeto: a lista de obras passa a trazer o "Responsável Acompanhamento"
-- para que o administrador atribua obras ao usuário a partir desse campo.
-- Reaplicável. Não altera obras, permissões nem responsáveis.
begin;
create or replace function public.secap_admin_permission_works(p_project text,p_offset integer default 0) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare fid text;
begin
 if auth.uid() is null or not coalesce(public.is_admin(),false) then raise exception 'Acesso restrito.' using errcode='42501';end if;
 if p_offset is null or p_offset<0 then raise exception 'Página inválida.';end if;
 select f->>'id' into fid
   from public.app_state s
   cross join lateral jsonb_array_elements(coalesce(s.body->'projects','[]')) p
   cross join lateral jsonb_array_elements(coalesce(p->'fields','[]')) f
  where s.id=1 and p->>'id'=p_project and lower(f->>'name') ~ '^respons.vel\s+(pelo\s+)?acompanhamento'
  limit 1;
 return jsonb_build_object(
   'total',(select count(*) from public.obras where project_id=p_project),
   'acompanhamentoField',fid,
   'rows',(select coalesce(jsonb_agg(to_jsonb(w) order by w.id),'[]') from(
     select id,nome,coalesce(dados->>'codigo',dados->>'ID',id) as codigo,
            case when fid is null then null else nullif(trim(dados->>fid),'') end as acompanhamento
       from public.obras where project_id=p_project order by id limit 500 offset p_offset)w));
end $$;
revoke all on function public.secap_admin_permission_works(text,integer) from public,anon;
grant execute on function public.secap_admin_permission_works(text,integer) to authenticated;
notify pgrst,'reload schema';
commit;
select 'Lista de obras com Responsável Acompanhamento atualizada com sucesso' as resultado;
