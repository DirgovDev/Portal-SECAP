# Marcos do Projeto no BI

Atualização da interface dos marcos, mantendo as configurações e o banco existentes.

Status disponíveis na caixa de seleção:

- Em andamento: azul (#007EFF).
- Concluído: verde (#00DE94).
- Iniciado: branco (#FFFFFF), com texto escuro e borda para leitura.
- Cancelado: preto (#000000).
- Paralisado: vermelho (#DC2626).
- Em planejamento: amarelo (#FFBF00).

O status antigo “Em progresso” passa a ser exibido como “Em andamento”. O status antigo que aparecia como “Cancelado” vermelho continua com o significado de Cancelado, agora preto. Não é convertido em Paralisado. Os marcos existentes não são apagados.

Clique no responsável (ou no botão +) para selecionar um usuário cadastrado e aprovado, com busca por nome/e-mail e carregamento de 50 por vez, ou escolha “Digitar nome” para indicar outra pessoa. O nome e a identificação da conta selecionada são guardados no marco; nomes digitados não criam contas. Use “Sem responsável” para limpar a atribuição.

Alterações de status e responsável informam valores anterior e atualizado à auditoria do BI. As permissões de edição existentes continuam sendo verificadas. A conclusão mantém o comportamento anterior de ajustar o progresso para 100%.

Para quem já aplicou a atualização anterior da agenda/auditoria, não é necessário novo SQL: a busca utiliza a consulta de usuários já existente. Atribuir responsável não envia e-mail nem concede acesso ao projeto. Testes locais de interface passaram.
