# Notificação semanal por e-mail

Toda **segunda-feira às 08:00** (horário de Brasília), cada conta vinculada a obras recebe um e-mail com a lista das **suas obras que não tiveram nenhuma edição na semana anterior** (segunda a domingo).

- "Conta vinculada" = conta com obras pelo **Responsável Acompanhamento** ou pela seleção individual em **Administração → Permissões do projeto**.
- "Sem edição" = nenhuma alteração registrada na auditoria naquela semana (por qualquer pessoa ou pela sincronia com a planilha).
- Contas de administrador não recebem.
- Cada envio fica na **Auditoria** como “Notificação semanal enviada”, com a semana, o e-mail e a lista de obras. A mesma conta não é notificada duas vezes na mesma semana.

## No portal

**Registro semanal → Notificação semanal por e-mail**:
- **Ver quem será notificado**: lista as contas e as obras sem edição da semana anterior, com a situação (Pendente, Enviado, Gerado em teste, Erro).
- **Enviar agora**: envia na hora para as contas ainda não notificadas.

## Instalação

1. No SQL Editor do Supabase do portal, execute `supabase/security/weekly_notify.sql` (resultado: “Notificação semanal instalada com sucesso”). Requer `responsible_acompanhamento_access.sql`.
2. Copie `weekly-notify.example.json` para `data/weekly-notify.json` (é isso que liga o envio automático de segunda-feira).
3. Configure o servidor de e-mail em `"smtp"`:
   - **Gmail / Google Workspace**: `host` `smtp.gmail.com`, `porta` 587, `seguranca` `starttls`, `usuario` = o e-mail, `senha` = **senha de app** (Conta Google → Segurança → Senhas de app; exige verificação em 2 etapas), `remetente` = o mesmo e-mail.
   - **Outlook / Microsoft 365**: `host` `smtp.office365.com`, `porta` 587, `seguranca` `starttls`.
   - **Servidor da Prefeitura**: peça host, porta e credenciais à TI.
4. `service_role_key` pode ficar vazio: usa a mesma de `data/sheet-sync.json`.
5. Reinicie o portal (`python server.py`). Deve aparecer “Notificação semanal por e-mail: agendada”.

A pasta `data/` não vai para o Git; a senha do e-mail fica só neste computador.

## Modo teste

Com `"host"` vazio, nada é enviado: os e-mails são gerados como arquivos `.eml` em `data/weekly-notify-outbox/` (abrem no Outlook ou em qualquer leitor de e-mail) e registrados na Auditoria como “gerada (modo teste, sem envio)”.

## Linha de comando

```powershell
python weekly_notify.py --previa
```
```powershell
python weekly_notify.py --enviar 2026-11-09
```
(`--enviar` sem data usa a semana anterior.)

## Observações

- O envio automático só acontece com o portal ligado. Se ele estiver desligado na segunda às 08:00, o envio é feito assim que o portal voltar a rodar naquela semana.
- Histórico: `data/weekly-notify.log`.

## Testes realizados

Banco local, com vínculo temporário (desfeito): consulta das obras sem edição por conta, geração dos e-mails em modo teste (texto e HTML), registro na Auditoria e na tabela de controle, bloqueio de reenvio na mesma semana e recusa de acesso sem sessão de administrador. Os registros de teste foram removidos. O envio real por SMTP depende das credenciais (passo 3).
