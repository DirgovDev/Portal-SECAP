-- Somente leitura. Executar no mesmo banco conectado ao portal.
select p.id as usuario_id, p.name as nome_salvo_na_conta,
 count(e.id) filter(where e.who in ('Nome não informado','Usuário não informado') or e.who='') as eventos_com_nome_ausente,
 secap_private.audit_actor_name(p.id) as nome_resolvido
from public.profiles p left join public.secap_audit_events e on e.actor=p.id
group by p.id,p.name order by p.name;
select count(*) as eventos_sem_identificador_do_autor from public.secap_audit_events where actor is null;
