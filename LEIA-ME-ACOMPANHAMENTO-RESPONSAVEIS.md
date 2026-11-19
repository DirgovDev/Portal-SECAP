# Acompanhamento e responsáveis das obras

Esta atualização foi feita sobre `Portal-SECAP (9).zip`. Preserva as configurações do Supabase e as alterações existentes no arquivo enviado.

## Ativação

1. Use os arquivos desta versão do portal.
2. No SQL Editor do MESMO banco utilizado pelo portal, execute todo o conteúdo de `supabase/security/work_responsibility_required.sql`.
3. Confirme “Responsável obrigatório por obra ativado com sucesso”.
4. Reinicie o servidor, se necessário, e atualize o navegador com Ctrl+F5.

O SQL é reaplicável. Não apaga registros e não escolhe responsáveis automaticamente. Se o colega usar o mesmo banco já atualizado, basta aplicar uma vez; para outro banco/local, execute o SQL também nesse ambiente. O arquivo está incluído no ZIP.

## O que mudou

- Cartões do acompanhamento não repetem a situação da obra. Mostram os responsáveis pelo nome, com iniciais circulares. Dois nomes ficam à vista; quando houver mais, o contador e a descrição acessível indicam os demais.
- O botão de responsáveis permite selecionar múltiplas contas aprovadas, buscar por nome/e-mail ou adicionar um nome digitado.
- As atribuições são armazenadas no campo Responsável da obra (ou no campo associado a responsável no projeto), com nomes separados por ponto e vírgula. Os formulários e demais telas continuam usando esse campo existente. A seleção não envia convites nem cria contas.
- Mover uma obra entre etapas reconhecidas do Kanban agora salva seu status no banco e atualiza o registro do projeto. O sucesso só aparece após confirmação da gravação.
- O Kanban passa a usar o status real da obra. Posições antigas guardadas apenas no navegador não são usadas para alterar dados do projeto. Nenhum status antigo é reescrito automaticamente.
- Edições do status na obra também determinam a coluna na próxima renderização do acompanhamento.
- Os nomes convencionais Planejamento, Em andamento, Em atenção e Concluído correspondem a Em planejamento, Em andamento, Ponto de Atenção e Concluído. Opções existentes com prefixos numéricos são preservadas quando houver correspondência. Etapas personalizadas sem situação reconhecida não alteram a obra silenciosamente: o portal pede usar uma situação reconhecida.

## Obrigatoriedade e permissões

Toda nova gravação exige ao menos um responsável, inclusive importações quando o SQL estiver ativo. Obras antigas sem responsável continuam disponíveis para consulta, com “Definir responsáveis” no cartão. Para movê-las, informe o responsável primeiro, ou solicite isso a quem tem permissão para editar esse campo.

Para mover, o usuário precisa poder editar o campo de status da obra. Para atribuir responsáveis, precisa poder editar o campo correspondente. Ser responsável NÃO concede acesso ao projeto, permissão de edição ou responsabilidade pelos demais campos. As regras administrativas existentes foram mantidas para discutirmos essa organização separadamente.

Na edição da obra, use “Selecionar responsáveis” ou digite nomes separados por ponto e vírgula. A seleção abre junto ao formulário para preservar os outros campos já preenchidos.

## Verificação realizada

Testes locais de interface: confirmação antes de atualizar a tela, falha de gravação sem modificar o status local, permissão de campo, responsável obrigatório, dois usuários selecionados, cartões sem status repetido e obra→Kanban.

Testes em PostgreSQL local de teste: SQL reaplicável, obras antigas preservadas, rejeição de gravação sem responsável, vários nomes, campo personalizado e preservação da regra granular de campos existente. O banco ativo do usuário não foi acessado ou alterado.

## Atualização: responsável opcional

O campo **Responsável pela próxima ação** voltou a ser opcional. Editar, salvar ou mover uma obra no Acompanhamento não exige mais preenchê-lo. O acesso às obras é definido pelo **Responsável Acompanhamento** e pelas Permissões do projeto, que continuam preenchendo esse campo automaticamente com as contas vinculadas.

No banco, execute `supabase/security/work_responsibility_optional.sql` (resultado: “Responsável pela próxima ação agora é opcional”). Não execute novamente `work_responsibility_required.sql`, ou a obrigatoriedade volta.
