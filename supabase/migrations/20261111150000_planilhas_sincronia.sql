-- SECAP: mantém public.planilhas_importadas coerente com public.obras.
-- Ao excluir obras importadas, o total da planilha é recalculado e a planilha é removida quando não sobra nenhuma obra.
-- Roda no banco (security definer), então não depende de policy de UPDATE e vale para qualquer origem de exclusão.

create or replace function public.sync_planilha_after_obra_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  restante integer;
begin
  if old.planilha_id is null then
    return old;
  end if;

  select count(*) into restante from public.obras where planilha_id = old.planilha_id;

  if restante = 0 then
    delete from public.planilhas_importadas where id = old.planilha_id;
  else
    update public.planilhas_importadas set total_obras = restante where id = old.planilha_id;
  end if;

  return old;
end;
$$;
revoke all on function public.sync_planilha_after_obra_delete() from public, anon, authenticated;

drop trigger if exists obras_sync_planilha on public.obras;
create trigger obras_sync_planilha
  after delete on public.obras
  for each row execute function public.sync_planilha_after_obra_delete();

-- Limpeza única do que já ficou inconsistente: recalcula totais e remove planilhas sem nenhuma obra.
update public.planilhas_importadas p
   set total_obras = (select count(*) from public.obras o where o.planilha_id = p.id)
 where total_obras <> (select count(*) from public.obras o where o.planilha_id = p.id);

delete from public.planilhas_importadas p
 where not exists (select 1 from public.obras o where o.planilha_id = p.id);

notify pgrst, 'reload schema';
