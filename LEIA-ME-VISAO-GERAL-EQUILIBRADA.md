# Visão Geral — opção 3 (equilibrada)

Base: Portal-SECAP-main.zip enviado em 19/11/2026.

## Alterações

- Quatro indicadores: total de obras, em andamento, concluídas e obras que precisam de atenção.
- Lista de obras que precisam de atenção ao lado do gráfico de situação.
- Atenção reúne, sem duplicar a mesma obra: atraso, paralisação, ponto de atenção e ausência de alteração há mais de 10 dias; exclui concluídas e canceladas.
- Lista de próximas entregas, baseada nos prazos das obras para os próximos 30 dias, excluindo concluídas/canceladas; abre a obra e permite consultar todas as entregas desse período.
- Gráfico de barras nas cores de situação já configuradas no portal; clicar na barra consulta as obras correspondentes.
- Layout responsivo com estilos limitados à área redesenhada.
- Removidos os controles “Contêineres desta aba” em Acompanhamento e Calendário; esses caminhos passam a usar sua composição original, sem apagar configurações guardadas.
- Removido o botão “Projetos · fluxo principal”. Se houver vários quadros, um seletor compacto preserva a navegação entre eles.

## Preservado

O bloco “Quem editou recentemente” tem exatamente o mesmo código, HTML, consultas de auditoria e ações do ZIP original. A folha de estilos nova não modifica esse bloco. Os estilos anteriores permanecem iguais.

Licitações não foi adicionada. Não foram alterados dados, permissões, login, tabelas, migrações ou funções do Supabase.

## Usar

Utilize os arquivos deste ZIP no lugar da versão anterior, mantendo a configuração do seu ambiente. Reinicie o servidor do portal e atualize o navegador com Ctrl+F5. Não há SQL novo a executar.

## Verificação

Sintaxe dos scripts verificada. Testes de lógica com dados fictícios: quatro indicadores, agrupamento de atenção sem duplicidade, prazos e exclusão de concluídas/canceladas, clique do gráfico, listagem de próximas entregas e cenário sem obras. O trecho do painel “Quem editou recentemente” foi comparado byte a byte com o original. Não foi possível validar a renderização em navegador neste ambiente; o banco ativo não foi acessado.

## Remoção dos editores nas telas iniciais

Removida a barra Contêineres desta aba nas telas iniciais de Projetos e BI/Painéis (lista de pastas). Os cartões, informações e organizações salvas continuam disponíveis. As ferramentas internas dos painéis de projeto permanecem como antes. Não há alteração de SQL ou de permissões.
