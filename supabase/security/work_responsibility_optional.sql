-- Torna opcional o campo "Responsável pela próxima ação" das obras.
-- Desfaz a obrigatoriedade criada por work_responsibility_required.sql.
-- O acesso às obras continua definido pelo Responsável Acompanhamento e pelas
-- Permissões do projeto; a sincronização automática de responsáveis continua ativa.
-- Reaplicável. Não altera nenhuma obra.
-- ATENÇÃO: não execute novamente work_responsibility_required.sql, ou a obrigatoriedade volta.
begin;
drop trigger if exists secap_work_responsible_required on public.obras;
commit;
select 'Responsável pela próxima ação agora é opcional' as resultado;
