# Participantes da reunião

Esta versão substitui o comportamento anterior de agenda apenas privada para reuniões. Veja `LEIA-ME-ATUALIZACAO-AGENDA-AUDITORIA.md` para as instruções atuais.

Execute uma vez `supabase/security/agenda_audit_update.sql` no mesmo banco do portal. Ele já inclui a função de seleção de participantes.

A seleção é múltipla, com busca e carregamento de 50 usuários aprovados por vez, até 100 participantes por compromisso. Reuniões aparecem também para as contas selecionadas, com seus nomes. Apenas o organizador edita ou exclui; lembretes continuam privados.
