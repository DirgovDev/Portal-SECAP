# Permissões do projeto

Base: o ZIP “Portal-SECAP-Acompanhamento-Responsaveis (1)(1).zip” anexado pelo usuário. As funcionalidades de importação, cadastro, justificativas e seleção de responsáveis desse ZIP foram preservadas.

## O que mudou

Na Administração, “Permissões por campo” passou a se chamar “Permissões do projeto”. O administrador seleciona:

1. Um usuário cadastrado e aprovado.
2. O projeto/pasta.
3. Uma ou várias obras, identificadas pelo nome e ID.
4. Os campos que essa pessoa pode editar nas obras marcadas.

A lista consulta todas as obras do projeto no banco em páginas de 500, sem depender dos filtros da tela. Há busca e marcação múltipla. Campos não selecionados permanecem somente para leitura. Nenhuma obra selecionada significa nenhuma obra liberada para edição; sem campos selecionados, nenhum campo é liberado. A seleção limita a leitura e a edição por obra, diretamente no banco. Em Projetos e Acompanhamento, usuários comuns veem somente obras explicitamente selecionadas pelo administrador; sem seleção, não há obras visíveis. Todos os campos das obras atribuídas podem ser consultados, mas apenas os campos liberados podem ser editados. O administrador vê todas. A mesma obra pode ser selecionada para várias pessoas, com campos diferentes por pessoa.

Selecionar uma obra para um usuário também o torna responsável por ela, inclusive quando ele recebe somente visualização (nenhum campo editável). O campo de responsáveis é sincronizado com as contas selecionadas, e a mesma obra pode ter várias pessoas. Remover uma atribuição preserva as demais pessoas vinculadas.

## Instalar

1. Use os arquivos deste ZIP.
2. Abra uma consulta nova no SQL Editor do Supabase utilizado pelo portal.
3. Cole e execute TODO o arquivo `supabase/security/project_work_selection.sql`. O arquivo separado `Configurar-Permissoes-Projeto-Obras.sql` é idêntico.
4. Se aparecer o aviso do editor, escolha **Run without RLS**: o SQL já mantém a proteção RLS explícita.
5. Confira **Permissões do projeto atualizadas com sucesso**.
6. Reinicie o portal e atualize com Ctrl+F5. Após configurar o usuário, ele deve sair e entrar novamente para recarregar o acesso ao projeto.

Aplique apenas este SQL para esta entrega. Não é preciso reaplicar os scripts de permissões das entregas abandonadas.

O SQL preserva obras, históricos e usuários. Como o banco pode ter recebido as versões abandonadas, retira exclusivamente os gatilhos de justificativa obrigatória e de vínculo obrigatório de conta introduzidos por essas versões, incompatíveis com o funcionamento do ZIP-base mostrado na imagem. Restaura a validação de campos desse ZIP e acrescenta a seleção de obras. As tabelas das versões anteriores não são apagadas.

## Validação local

Interface e PostgreSQL: lista de 1.205 obras; busca e múltipla seleção; campos diferentes por usuário; bloqueio de edição em obra não selecionada; tentativa de mudar campo não liberado; configuração exclusiva de administrador; projeto isolado; reaplicação do SQL; nenhuma obra excluída. O banco do usuário não foi alterado diretamente.

## Verificação do projeto

Nova aba ao lado de Permissões do projeto. Selecione a pasta para consultar um resumo, buscar pessoas/obras/campos e expandir o cartão de cada conta. Os cartões mostram obras do Acompanhamento e campos editáveis, respeitando o perfil administrador, o acesso ao projeto e a permissão de edição. Sem seleção de obras, o usuário não pode consultar obras. Essa aba apenas consulta: não modifica permissões.

Para quem já instalou a entrega anterior, basta executar `supabase/security/project_permission_review.sql` (idêntico ao arquivo separado `Verificacao-Permissoes-Projeto.sql`) inteiro em uma nova consulta. Resultado: “Verificação do projeto e Acompanhamento atualizados com sucesso”. O instalador completo `project_work_selection.sql` também já inclui essa atualização; não precisa executar os dois.

O Acompanhamento consulta apenas a seleção da conta conectada e atualiza a consulta ao entrar na tela após 15 segundos. Erro na consulta não revela cartões antigos. Outras contas não podem consultar a verificação administrativa nem a seleção de terceiros.

## Correção de visualização e navegação

Execute `supabase/security/assigned_works_visibility.sql` (igual a `Restringir-Obras-e-Corrigir-Verificacao.sql`) inteiro em uma nova consulta no Supabase, após a versão de Permissões do projeto já instalada. Resultado: “Acesso às obras e verificação corrigidos com sucesso”. O instalador completo também já incorpora a regra. Use o ZIP atualizado e faça logout/login para recarregar as obras com as novas permissões.

A Administração agora reconhece a terceira aba na navegação, evitando o retorno indevido a Acesso ao sistema. A movimentação no Acompanhamento mantém a regra do ZIP-base: apenas quem possui permissão para editar o campo mapeado como Status do projeto pode alterar o status. Usuários sem essa permissão continuam visualizando suas obras.

## Responsáveis integrados à seleção de obras

Execute `supabase/security/work_responsibles_sync.sql` (igual ao arquivo separado `Sincronizar-Responsaveis-das-Obras.sql`) inteiro em nova consulta. Resultado: “Responsáveis sincronizados com as permissões do projeto”. O instalador completo também inclui essa regra. O script aplica a sincronização às seleções já salvas. As obras sem seleção registrada mantêm os nomes anteriores.

Ao salvar permissões, somente os responsáveis das obras selecionadas/removidas são atualizados, de forma atômica com as permissões. Nome da obra, status e demais campos não são regravados. O campo de responsável mapeado pelo projeto também é atualizado, quando diferente do padrão. A atualização é registrada pelo mecanismo de auditoria existente.

No Acompanhamento, o administrador vê o filtro Responsáveis ao lado de Todos os status. Pode escolher uma conta, um nome anterior de responsável ou Sem responsável. Esse filtro é de consulta e não muda vínculos nem permissões; não aparece para usuários comuns. O controle de edição de status permanece pela permissão do campo Status do projeto.

## Acesso automático pelo Responsável Acompanhamento

O campo **Responsável Acompanhamento** passa a ser o fator principal de acesso às obras.

Execute `supabase/security/responsible_acompanhamento_access.sql` inteiro no SQL Editor do banco usado pelo portal. Resultado: “Acesso pelo Responsável Acompanhamento ativado com sucesso”. Reaplicável; não altera obras nem apaga permissões.

Em Administração → Permissões do projeto, depois de escolher usuário e projeto, o passo **3. Responsável Acompanhamento vinculado a esta conta** mostra um botão por nome existente no campo (com a quantidade de obras). Ao vincular um nome, a conta vê e trabalha automaticamente em todas as obras cujo Responsável Acompanhamento contenha esse nome — inclusive obras novas ou que passem a ter esse nome depois. Nomes compostos como “Heloísa / Hélen” valem para as duas pessoas. A comparação ignora acentos e maiúsculas.

No passo 4, as obras automáticas aparecem marcadas e bloqueadas (“Automática · nome”); marque ali apenas exceções individuais. Os campos editáveis continuam definidos no passo 5. Ao salvar, o campo Responsável das obras afetadas é sincronizado com as contas que as recebem.

Atenção: quem tiver permissão para editar o campo Responsável Acompanhamento pode, ao alterá-lo, mudar quem recebe a obra. Libere esse campo apenas para quem deve fazer essa distribuição.
