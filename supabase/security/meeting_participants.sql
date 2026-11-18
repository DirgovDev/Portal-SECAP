-- Executar uma vez no banco conectado ao portal. Não altera eventos ou permissões de projetos.
begin;
create or replace function public.secap_meeting_users(p_search text default '',p_offset integer default 0)
returns jsonb language plpgsql security definer set search_path='' as $$
declare query text; results jsonb;
begin
 if auth.uid() is null or not coalesce(public.is_member(),false) then raise exception 'Acesso não aprovado.' using errcode='42501';end if;
 query:=btrim(coalesce(p_search,''));
 if char_length(query)>100 or p_offset is null or p_offset<0 or p_offset>100000 then raise exception 'Consulta inválida.';end if;
 select coalesce(jsonb_agg(item order by sort_name,sort_email,id),'[]'::jsonb) into results from (
   select p.id,lower(coalesce(nullif(btrim(p.name),''),p.email)) as sort_name,lower(p.email) as sort_email,
    jsonb_build_object('id',p.id,'name',coalesce(nullif(btrim(p.name),''),p.email),'email',p.email) as item
   from public.profiles p
   where p.role in ('administrador','usuario') and nullif(btrim(p.email),'') is not null
    and (query='' or strpos(lower(coalesce(p.name,'')||' '||p.email),lower(query))>0)
   order by sort_name,sort_email,p.id limit 51 offset p_offset
 ) found;
 return jsonb_build_object('users',case when jsonb_array_length(results)>50 then results-50 else results end,'hasMore',jsonb_array_length(results)>50);
end $$;
revoke all on function public.secap_meeting_users(text,integer) from public,anon;
grant execute on function public.secap_meeting_users(text,integer) to authenticated;
notify pgrst, 'reload schema';
commit;
select 'Seleção de participantes instalada com sucesso' as resultado;
