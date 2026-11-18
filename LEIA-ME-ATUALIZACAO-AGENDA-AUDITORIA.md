# Atualização da agenda e auditoria

## Instalação no banco existente

1. Abra o SQL Editor do mesmo Supabase utilizado pelo portal.
2. Copie e execute TODO o conteúdo de `supabase/security/agenda_audit_update.sql`.
3. Confirme a mensagem “Agenda compartilhada e auditoria atualizadas com sucesso”.
4. Utilize os arquivos deste ZIP e atualize o navegador com Ctrl+F5.

Esse único script já inclui a consulta de participantes. Para esta atualização, não é necessário executar novamente os outros scripts de auditoria. O script é reaplicável e não remove registros. Ele depende das tabelas e funções da auditoria que já estavam presentes na versão anterior do portal.

## Agenda

A reunião é um único compromisso compartilhado com os participantes selecionados dentre as contas aprovadas. Aparece no calendário do organizador e dos convidados, com seus nomes cadastrados. O e-mail continua sendo usado internamente para identificar a conta, sem ser mostrado na lista de participantes do compromisso. Quando falta nome no perfil, a tela informa “Participante sem nome cadastrado”.

Apenas o organizador pode editar/excluir. Convidados têm somente leitura. Alterações de horário/data refletem o mesmo registro; remover um participante remove seu acesso. Lembretes privados continuam somente do titular. As regras também são verificadas no banco.

Use “Atualizar agenda” para buscar alterações enquanto a tela estiver aberta. Ao entrar novamente na aba Calendário, os compromissos também são consultados. Não há envio de e-mail nem notificação externa nesta atualização.

Participantes antigos identificados somente por nome precisam ser selecionados pela conta correspondente para que tenham acesso; o sistema não adivinha a identidade de pessoas com nomes iguais. Reuniões antigas com e-mails cadastrados válidos passam a ser compartilhadas após instalar esta atualização.

## Auditoria

- Uma mudança: Campo, Registro Anterior e Registro Atualizado aparecem na tabela principal, com quebra de linha para leitura.
- Duas ou mais mudanças no lote: essas três colunas mostram “—”; clique em Ação para abrir tudo.
- A janela exibe Data e hora antes de Ação, responsável, motivo, campos e valores completos, além de Recuperação.
- Recuperação continua exigindo “Concordo em voltar” e registra a operação. Nos lotes novos, os botões dependem de vínculo verificável com os eventos reais do banco. Quando esse vínculo não existe, a operação fica indisponível. Os registros antigos são preservados.
- “Histórico de BI”, ao lado de “Histórico arquivado”, abre a auditoria específica do BI; não há mais a coluna BI na tabela principal.
- BI e auditoria geral são separados no banco antes da paginação e dos filtros de datas, com até 50 registros por página. Ambos têm períodos recentes e arquivados. Registros antigos de BI só podem ser classificados quando já contêm identificação de origem ou ação explícita do BI.

## Verificação

Testes locais de PostgreSQL e interface passaram: privacidade, nomes, leitura do convidado, bloqueio de edição/exclusão, remoção de acesso, separação e paginação de BI, detalhes e vínculo de recuperação. Configurações do Supabase existentes preservadas. O banco ativo do usuário não foi alterado por esta entrega.

## Correção de dependência de nome do responsável

Se aparecer `function secap_private.audit_entry_name(jsonb) does not exist`, execute somente `supabase/security/audit_name_dependency_fix.sql` no banco em uso. O resultado deve ser “Dependências da auditoria corrigidas com sucesso”. Depois clique em Atualizar na Auditoria. Não é necessário substituir os arquivos do portal para esta correção. O SQL completo `agenda_audit_update.sql` deste ZIP também foi corrigido para instalar as duas funções auxiliares antes das consultas. Nenhum registro é removido.

## Unificação de duplicidades

Execute `supabase/security/audit_deduplicate.sql` no banco usado pelo portal para unificar o resumo da edição em lote com o evento real da mesma alteração. A consulta mantém a linha “Alterou campo”, sua identificação da obra, data e hora, valores e botão Recuperar. O motivo e a checklist do resumo ficam associados ao evento real. Os registros originais não são apagados. O vínculo compara projeto, obra, campo, autoria, valores e sequência temporal. Campos sem evento correspondente continuam visíveis; mudanças de usuários diferentes não são unificadas. A correção é feita no banco, antes de paginar e filtrar as datas. O script completo `agenda_audit_update.sql` já inclui esta atualização.
