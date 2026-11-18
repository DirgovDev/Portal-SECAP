# Auditoria, filtros e recuperação

## Instalação obrigatória no banco utilizado pelo portal

Execute TODO o arquivo atualizado `supabase/security/audit_admin.sql` no SQL Editor do Supabase utilizado pelo portal, depois de já ter instalado `project_access.sql` e as migrações do projeto. Pode executar novamente mesmo se já instalou a edição anterior. Não é necessário reiniciar ou apagar o banco. Atualize o navegador com Ctrl+F5.

O SQL está preparado e foi testado em PostgreSQL isolado. Não foi aplicado ao banco local do seu computador por esta atualização.

## Consulta

- Registros recentes: últimos 40 dias de calendário, incluindo hoje.
- Histórico arquivado: botão ao lado de Atualizar, mostrando registros anteriores aos 40 dias. Mantém também os anteriores a três meses, sem exclusão automática.
- A página lista as datas disponíveis. Use Data inicial, Data final e Ver datas selecionadas, ou Ver tudo para todas as datas da seção atual.
- O histórico permanece no banco. Essa separação por período não é uma cópia de backup e não envia arquivos ao Google.

## Recuperação

- Apenas administradores. A coluna Recuperação abre a comparação de valores, projeto, obra e campo. Só o botão Concordo em voltar executa a recuperação; Cancelar não altera nada.
- O valor anterior substitui o atual apenas no campo correspondente. O restante da obra é preservado.
- O servidor registra automaticamente o usuário, a data, o campo, os valores e o identificador da alteração recuperada. O histórico original continua disponível.
- Se o campo mudou novamente ou a alteração já foi recuperada, a operação é recusada. Atualize antes de tentar outra alteração.
- A recuperação é habilitada para alterações de campos das obras capturadas no servidor APÓS instalar este SQL. Registros legados sem identificação segura da obra e do campo mostram Indisponível; não é seguro adivinhar seu destino. Criação/exclusão de obras, permissões e alterações gerais de configuração não são revertidas por esse botão.
- A tabela de novos eventos não permite edição/exclusão pelo cliente do portal. Administradores do banco continuam sujeitos às permissões administrativas do próprio banco.

## Integrações futuras

Google Sheets e Drive NÃO foram integrados nem agendados. Nenhum registro será apagado ou enviado automaticamente após três meses. A exportação trimestral e a política de backup ficam para uma próxima etapa.

## Verificação

Testes de PostgreSQL isolado: aplicação repetida do SQL, acesso administrativo, recusa de usuário comum, confirmação, recuperação atômica com autoria, bloqueio de repetição e conflito, campos customizados, zero/falso e remoção de campo antes ausente. Verificação JavaScript: sintaxe, limites de 40 dias, histórico antigo e ordem das oito colunas.


## Consulta paginada e organização atualizada

- Execute novamente TODO o arquivo atualizado `supabase/security/audit_admin.sql`, mesmo tendo aplicado uma versão anterior. Instala a consulta paginada, os índices e a preservação dos registros legados. Não elimina o histórico.
- A Auditoria não utiliza mais a barra Contêineres desta aba, nem controles de adicionar/organizar. Layouts antigos salvos para esta aba são ignorados, sem afetar as demais abas.
- Filtros e intervalo das datas ficam à direita. O intervalo é exibido como 01/03 – 10/04; quando atravessa anos, mostra também os anos.
- A consulta retorna no máximo 50 registros, ordenados por data e identificador. Use Anterior/Próxima. Ver tudo significa todas as datas do período, com paginação; não carrega todo o histórico de uma vez.
- Recentes mostra 40 dias incluindo hoje. Histórico arquivado só é consultado ao clicar e abre os 40 dias imediatamente anteriores. Os botões 40 dias anteriores/seguintes percorrem períodos mais antigos sem apagar registros.
- Filtros de data e paginação são aplicados no PostgreSQL. O horário de referência é America/Sao_Paulo.
- A inicialização do portal deixa de retornar o histórico completo no documento de estado. O histórico antigo é preservado e indexado para consulta paginada.
- Alterações de campos das obras são capturadas pelo servidor, guardando apenas o campo alterado e os valores anterior/atualizado, com os identificadores necessários. Não guarda uma cópia completa da obra em cada evento. Evita duplicar essas alterações no histórico gerado pelo navegador.
- Google Sheets/Drive continuam sem integração, agendamento ou descarte automático.

Validação adicional em PostgreSQL isolado: aplicação repetida do script, mais de 125 eventos, páginas de 50 sem duplicação, filtros de datas, períodos arquivados e proteção administrativa. A aplicação no banco local continua pendente de execução pelo responsável.


## Visual compacto e calendário de disponibilidade

- Faixa de consulta compacta: título e intervalo de datas à esquerda; data inicial/final e botões à direita, conforme a referência enviada.
- Calendário próprio: somente os dias do período com registros aparecem em preto e podem ser escolhidos. Dias sem registros ou fora do período aparecem esmaecidos. Não há legenda adicional no portal. A mesma regra vale para recentes e arquivo.
- É necessário reaplicar TODO o SQL atualizado `supabase/security/audit_admin.sql` para retornar as datas exatas que possuem registros; não se limita às datas dos primeiros 50 resultados. A consulta continua paginada.
- Títulos longos das obras são limitados a duas linhas no cabeçalho, com reticências. O nome completo continua no campo da obra e no título ao passar o mouse.
- Configurar seções e campos, Editar dados e Fechar têm espaço reservado e ficam alinhados dentro do cabeçalho. Em telas estreitas, o layout se reorganiza.
- Conferência no navegador em prévia isolada, sem banco real: cores dos dias e seleção de data, limite de duas linhas e todos os botões dentro do cabeçalho.


## Correção de alterações involuntárias e autoria

- Campos de seleção preservam exatamente valores importados, mesmo quando eles não fazem parte da lista atual de opções. Isso inclui variações como SIM, códigos de macroetapa e tipos de projeto antigos.
- Salvar um campo não limpa os campos ausentes/desabilitados nem normaliza valores que permaneceram iguais no formulário. Limpar um campo deliberadamente continua permitido.
- A auditoria continua registrando alterações reais. Não oculta os eventos anteriores de campos que foram esvaziados antes da correção.
- O nome do responsável é obtido do perfil, do cadastro de solicitação de acesso ou do nome de cadastro da autenticação. Esses nomes servem apenas para exibição, nunca para permissões. Quando não existe nome cadastrado, mostra Nome não informado.
- Execute novamente TODO o SQL atualizado `supabase/security/audit_admin.sql` no banco do portal para corrigir a identificação de autoria. Os dados que já foram esvaziados não são restaurados automaticamente; use Recuperar nas alterações correspondentes após conferir os valores.
- Testes: edição apenas do status preserva tipo, macroetapa, SIM e texto; campos omitidos permanecem; limpeza intencional funciona; nome da solicitação de cadastro substitui e-mail no registro de autoria.


## Sincronização do nome pessoal com a auditoria

A tela Meu perfil antes alterava somente o nome dentro do estado do portal. O registro de auditoria do servidor consulta public.profiles, portanto podia mostrar Nome não informado mesmo com nome na tela.

Para instalar esta correção:
1. Execute TODO o arquivo atualizado supabase/security/audit_admin.sql.
2. Abra a nova versão do portal e atualize com Ctrl+F5.
3. Em Meu perfil, confira seu nome e clique uma vez em Salvar informações.
4. Abra Auditoria e clique em Atualizar.

O nome agora é salvo somente na própria conta autenticada, sem alterar cargo ou permissões. Na entrada, o portal usa o nome salvo na conta. Registros anteriores com UUID do autor e nome ausente são resolvidos usando o cadastro atual. Registros legados sem identificação segura não recebem autoria inventada.


## Áreas pessoais e nomes legados

- Meu perfil e Minhas anotações deixam de aplicar o organizador de contêineres, assim como Auditoria. Não exibem Minha visualização, Adicionar ou Organizar contêineres. Os dados pessoais não são removidos.
- Nomes legados agora são resolvidos também pelo UUID do autor quando o texto histórico é Nome não informado. O texto padrão não impede a busca do nome na solicitação de cadastro.
- Execute o SQL atualizado audit_admin.sql no mesmo banco utilizado pelo portal. Agora o resultado final contém Atualização da Auditoria aplicada com sucesso.
- Atualize o novo portal com Ctrl+F5, abra Meu perfil e salve seu nome uma vez. A Auditoria avisa quando sua conta ainda está sem nome salvo no servidor.
- Não houve acesso ao seu banco nesta atualização. Se continuar sem nome, execute supabase/security/diagnostico_nomes.sql e confira o nome_salvo_na_conta e nome_resolvido. O diagnóstico é somente leitura. Eventos sem identificador de autoria não recebem nomes inventados.
