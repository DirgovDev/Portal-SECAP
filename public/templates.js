const sourceFieldCatalog = [
  {
    id: 'codigo',
    name: 'ID',
    type: 'text',
    group: 'Essenciais',
    sourceLabel: 'ID',
    help: 'Origem de referência: PIPELINE, coluna A.',
  },
  {
    id: 'orgao',
    name: 'Órgão responsável',
    type: 'text',
    group: 'Essenciais',
    sourceLabel: 'Orgão',
    help: 'Origem de referência: PIPELINE, coluna B.',
    required: true,
  },
  {
    id: 'nome',
    name: 'Nome da obra ou iniciativa',
    type: 'text',
    group: 'Essenciais',
    sourceLabel: 'Nome do Projeto',
    help: 'Origem de referência: PIPELINE, coluna C.',
    required: true,
  },
  {
    id: 'tipo',
    name: 'Tipo de Projeto',
    type: 'select',
    group: 'Essenciais',
    sourceLabel: 'Tipo de Projeto',
    help: 'Origem de referência: PIPELINE, coluna D.',
    options: [
      'Obra de infraestrutura',
      'Obra civil',
      'Reforma',
      'Serviço',
      'Estudo ou projeto',
      'Outro',
    ],
  },
  {
    id: 'sei',
    name: 'SEI',
    type: 'text',
    group: 'Acompanhamento',
    sourceLabel: 'SEI',
    help: 'Origem de referência: PIPELINE, coluna E.',
  },
  {
    id: 'observacao',
    name: 'Observação',
    type: 'long',
    group: 'Acompanhamento',
    sourceLabel: 'Observação',
    help: 'Origem de referência: PIPELINE, coluna F.',
  },
  {
    id: 'etapa',
    name: 'Macroetapa',
    type: 'select',
    group: 'Essenciais',
    sourceLabel: 'Macroetapa',
    help: 'Origem de referência: PIPELINE, coluna G.',
    options: [
      'Em estruturação',
      'Planejamento',
      'Preparatório para contratação',
      'Contratação',
      'Mobilização',
      'Execução',
      'Encerramento',
    ],
  },
  {
    id: 'detalhamento',
    name: 'Detalhamento Tipo de Projeto',
    type: 'text',
    group: 'Localização',
    sourceLabel: 'Detalhamento Tipo de Projeto',
    help: 'Origem de referência: PIPELINE, coluna H.',
  },
  {
    id: 'regiao',
    name: 'Região',
    type: 'select',
    group: 'Localização',
    sourceLabel: 'Região',
    help: 'Origem de referência: PIPELINE, coluna I.',
    options: [
      'Centro',
      'Leste',
      'Noroeste',
      'Norte',
      'Oeste',
      'Sudoeste',
      'Sul',
      'Várias / não definida',
    ],
  },
  {
    id: 'bairro',
    name: 'Bairro',
    type: 'text',
    group: 'Localização',
    sourceLabel: 'Bairro',
    help: 'Origem de referência: PIPELINE, coluna J.',
  },
  {
    id: 'id_bairro',
    name: 'Id Bairro',
    type: 'text',
    group: 'Localização',
    sourceLabel: 'Id Bairro',
    help: 'Origem de referência: PIPELINE, coluna K.',
  },
  {
    id: 'corredor',
    name: 'Corredor',
    type: 'text',
    group: 'Localização',
    sourceLabel: 'Corredor',
    help: 'Origem de referência: PIPELINE, coluna L.',
  },
  {
    id: 'origem_valor',
    name: 'Origem do Valor',
    type: 'text',
    group: 'Recursos e instrumentos',
    sourceLabel: 'Origem do Valor',
    help: 'Origem de referência: PIPELINE, coluna M.',
  },
  {
    id: 'tem_projeto',
    name: 'Tem projeto',
    type: 'select',
    group: 'Acompanhamento',
    sourceLabel: 'Tem projeto',
    help: 'Origem de referência: PIPELINE, coluna N.',
    options: ['Sim', 'Não', 'Em elaboração'],
  },
  {
    id: 'valor_projeto',
    name: 'Valor Estimado Execução Projeto',
    type: 'currency',
    group: 'Financeiro',
    sourceLabel: 'Valor Estimado Execução Projeto',
    help: 'Origem de referência: PIPELINE, coluna O.',
  },
  {
    id: 'valor',
    name: 'Investimento previsto da obra',
    type: 'currency',
    group: 'Financeiro',
    sourceLabel: 'Valor Estimado Execução Obra',
    help: 'Estimativa de execução da obra. Não somar novamente ao Valor Total ou aos subtotais anuais.',
  },
  {
    id: 'executado',
    name: 'Valor Executado',
    type: 'currency',
    group: 'Financeiro',
    sourceLabel: 'Valor Executado',
    help: 'Origem de referência: PIPELINE, coluna Q.',
  },
  {
    id: 'captado',
    name: 'Valor Captado',
    type: 'currency',
    group: 'Financeiro',
    sourceLabel: 'Valor Captado',
    help: 'Origem de referência: PIPELINE, coluna R.',
  },
  {
    id: 'contrapartida',
    name: 'Contrapartida Municipio',
    type: 'currency',
    group: 'Financeiro',
    sourceLabel: 'Contrapartida Municipio',
    help: 'Origem de referência: PIPELINE, coluna S.',
  },
  {
    id: 'fonte',
    name: 'Fonte de Recursos',
    type: 'select',
    group: 'Recursos e instrumentos',
    sourceLabel: 'Fonte de Recursos',
    help: 'Origem de referência: PIPELINE, coluna T.',
    options: [
      'Recurso federal',
      'Financiamento',
      'Tesouro',
      'Emenda',
      'Termo de compromisso',
      'Outra',
      'A definir',
    ],
  },
  {
    id: 'programa',
    name: 'Programa / Gestor',
    type: 'text',
    group: 'Recursos e instrumentos',
    sourceLabel: 'Programa / Gestor',
    help: 'Origem de referência: PIPELINE, coluna U.',
  },
  {
    id: 'financiadora',
    name: 'Unidade Financiadora',
    type: 'text',
    group: 'Recursos e instrumentos',
    sourceLabel: 'Unidade Financiadora',
    help: 'Origem de referência: PIPELINE, coluna V.',
  },
  {
    id: 'financiar',
    name: 'Sugestão de Financiar',
    type: 'boolean',
    group: 'Recursos e instrumentos',
    sourceLabel: 'Sugestão de Financiar',
    help: 'Origem de referência: PIPELINE, coluna W.',
  },
  {
    id: 'status',
    name: 'Status do Projeto',
    type: 'select',
    group: 'Essenciais',
    sourceLabel: 'Status do Projeto',
    help: 'Origem de referência: PIPELINE, coluna X.',
    options: [
      'Em planejamento',
      'Em andamento',
      'Paralisado',
      'Concluído',
      'Cancelado',
      'Em análise',
    ],
  },
  {
    id: 'inicio',
    name: 'Data Início do Projeto',
    type: 'date',
    group: 'Prazos e marcos',
    sourceLabel: 'Data Início do Projeto',
    help: 'Origem de referência: PIPELINE, coluna Y.',
  },
  {
    id: 'prev_planejamento',
    name: 'Previsão Planejamento',
    type: 'date',
    group: 'Prazos e marcos',
    sourceLabel: 'Previsão Planejamento',
    help: 'Origem de referência: PIPELINE, coluna Z.',
  },
  {
    id: 'prev_preparatorio',
    name: 'Previsão Preparatório',
    type: 'date',
    group: 'Prazos e marcos',
    sourceLabel: 'Previsão Preparatório',
    help: 'Origem de referência: PIPELINE, coluna AA.',
  },
  {
    id: 'prev_contratacao',
    name: 'Previsão Contratação',
    type: 'date',
    group: 'Prazos e marcos',
    sourceLabel: 'Previsão Contratação',
    help: 'Origem de referência: PIPELINE, coluna AB.',
  },
  {
    id: 'prev_mobilizacao',
    name: 'Previsão Mobilizaçao',
    type: 'date',
    group: 'Prazos e marcos',
    sourceLabel: 'Previsão Mobilizaçao',
    help: 'Origem de referência: PIPELINE, coluna AC.',
  },
  {
    id: 'execucao_origem',
    name: 'Previsão de execução — conteúdo de origem',
    type: 'text',
    group: 'Prazos e marcos',
    sourceLabel: 'Previsão Execução',
    help: 'A coluna original mistura valores que podem representar duração. Confirme a unidade antes de transformar em data. O calendário não usa este campo.',
  },
  {
    id: 'prazo',
    name: 'Previsão Encerramento',
    type: 'date',
    group: 'Prazos e marcos',
    sourceLabel: 'Previsão Encerramento',
    help: 'Origem de referência: PIPELINE, coluna AE.',
  },
  {
    id: 'tem_termo',
    name: 'Termo de compromisso',
    type: 'boolean',
    group: 'Recursos e instrumentos',
    sourceLabel: 'Termo de compromisso',
    help: 'Origem de referência: PIPELINE, coluna AF.',
  },
  {
    id: 'prioridade',
    name: 'Prioridade',
    type: 'select',
    group: 'Essenciais',
    sourceLabel: 'Prioridade',
    help: 'Origem de referência: PIPELINE, coluna AG.',
    options: ['Muito alta', 'Alta', 'Média', 'Baixa', 'Ainda não definida'],
  },
  {
    id: 'numero_termo',
    name: 'Número Termo',
    type: 'text',
    group: 'Recursos e instrumentos',
    sourceLabel: 'Número Termo',
    help: 'Origem de referência: PIPELINE, coluna AH.',
  },
  {
    id: 'classificacao_origem',
    name: 'Classificação de origem — revisar',
    type: 'text',
    group: 'Acompanhamento',
    sourceLabel: 'AINDA NÃO DEFINIDA',
    help: 'Coluna original “AINDA NÃO DEFINIDA”. Confirmar seu significado com a equipe antes de usar em indicadores.',
  },
  {
    id: 'contratacao',
    name: 'Contratação',
    type: 'text',
    group: 'Acompanhamento',
    sourceLabel: 'Contratação',
    help: 'Origem de referência: PIPELINE, coluna AJ.',
  },
  {
    id: 'solicitacoes_financeiras',
    name: 'SOLICITAÇÕES FINANCEIRAS',
    type: 'text',
    group: 'Recursos e instrumentos',
    sourceLabel: 'SOLICITAÇÕES FINANCEIRAS',
    help: 'Origem de referência: PIPELINE, coluna AK.',
  },
  {
    id: 'valor_total',
    name: 'VALOR TOTAL',
    type: 'currency',
    group: 'Financeiro',
    sourceLabel: 'VALOR TOTAL',
    help: 'Valor total informado na fonte. Conferir a relação com o investimento da obra e com os subtotais antes de consolidar.',
  },
  {
    id: 'total_2026',
    name: 'Valor Subtotal 2026',
    type: 'currency',
    group: 'Financeiro',
    sourceLabel: 'Valor Subtotal 2026',
    help: 'Origem de referência: PIPELINE, coluna AM.',
  },
  {
    id: 'total_2027',
    name: 'Valor Subtotal 2027',
    type: 'currency',
    group: 'Financeiro',
    sourceLabel: 'Valor Subtotal 2027',
    help: 'Origem de referência: PIPELINE, coluna AN.',
  },
  {
    id: 'total_2028',
    name: 'Valor Subtotal 2028',
    type: 'currency',
    group: 'Financeiro',
    sourceLabel: 'Valor Subtotal 2028',
    help: 'Origem de referência: PIPELINE, coluna AO.',
  },
  {
    id: 'federal_total',
    name: 'Valores Recursos Federais',
    type: 'currency',
    group: 'Financeiro',
    sourceLabel: 'Valores Recursos Federais',
    help: 'Origem de referência: PIPELINE, coluna AP.',
  },
  {
    id: 'federal_2026',
    name: 'Recursos Federais 2026.',
    type: 'currency',
    group: 'Financeiro',
    sourceLabel: 'Recursos Federais 2026.',
    help: 'Origem de referência: PIPELINE, coluna AQ.',
  },
  {
    id: 'federal_2027',
    name: 'Recursos Federais 2027',
    type: 'currency',
    group: 'Financeiro',
    sourceLabel: 'Recursos Federais 2027',
    help: 'Origem de referência: PIPELINE, coluna AR.',
  },
  {
    id: 'federal_2028',
    name: 'Recursos Federais 2028',
    type: 'currency',
    group: 'Financeiro',
    sourceLabel: 'Recursos Federais 2028',
    help: 'Origem de referência: PIPELINE, coluna AS.',
  },
  {
    id: 'municipal_total',
    name: 'Valor Recursos Municipais',
    type: 'currency',
    group: 'Financeiro',
    sourceLabel: 'Valor Recursos Municipais',
    help: 'Origem de referência: PIPELINE, coluna AT.',
  },
  {
    id: 'municipal_2026',
    name: 'Recursos Municipais 2026',
    type: 'currency',
    group: 'Financeiro',
    sourceLabel: 'Recursos Municipais 2026',
    help: 'Origem de referência: PIPELINE, coluna AU.',
  },
  {
    id: 'municipal_2027',
    name: 'Recursos Municipais 2027',
    type: 'currency',
    group: 'Financeiro',
    sourceLabel: 'Recursos Municipais 2027',
    help: 'Origem de referência: PIPELINE, coluna AV.',
  },
  {
    id: 'municipal_2028',
    name: 'Recursos Municipais 2028',
    type: 'currency',
    group: 'Financeiro',
    sourceLabel: 'Recursos Municipais 2028',
    help: 'Origem de referência: PIPELINE, coluna AW.',
  },
  {
    id: 'outros_total',
    name: 'Valor Recursos - Outros',
    type: 'currency',
    group: 'Financeiro',
    sourceLabel: 'Valor Recursos - Outros',
    help: 'Origem de referência: PIPELINE, coluna AX.',
  },
  {
    id: 'outros_2026',
    name: 'Recursos - Outros 2026',
    type: 'currency',
    group: 'Financeiro',
    sourceLabel: 'Recursos - Outros 2026',
    help: 'Origem de referência: PIPELINE, coluna AY.',
  },
  {
    id: 'outros_2027',
    name: 'Recursos - Outros 2027',
    type: 'currency',
    group: 'Financeiro',
    sourceLabel: 'Recursos - Outros 2027',
    help: 'Origem de referência: PIPELINE, coluna AZ.',
  },
  {
    id: 'outros_2028',
    name: 'Recursos - Outros 2028',
    type: 'currency',
    group: 'Financeiro',
    sourceLabel: 'Recursos - Outros 2028',
    help: 'Origem de referência: PIPELINE, coluna BA.',
  },
  {
    id: 'atualizado_por',
    name: 'Responsável pela Atualização',
    type: 'text',
    group: 'Acompanhamento',
    sourceLabel: 'Responsável pela Atualização',
    help: 'Origem de referência: PIPELINE, coluna BB.',
  },
  {
    id: 'atualizado_em',
    name: 'Data da última Atualização',
    type: 'date',
    group: 'Prazos e marcos',
    sourceLabel: 'Data da última Atualização',
    help: 'Origem de referência: PIPELINE, coluna BC.',
  },
];

let templateLibraryView = '',
  selectedTemplate = 'obras';

const extraOperationalFields = [
  {
    id: 'responsavel',
    name: 'Responsável pela próxima ação (opcional)',
    type: 'text',
    required: false,
    group: 'Essenciais',
    help: 'Pessoa que acompanhará a próxima providência. É diferente de quem atualizou a planilha.',
  },
  {
    id: 'proxima',
    name: 'Próxima providência',
    type: 'long',
    group: 'Essenciais',
    help: 'Descreva uma ação concreta: o que será feito e o resultado esperado.',
  },
  {
    id: 'prazo_acao',
    name: 'Prazo da próxima providência',
    type: 'date',
    group: 'Essenciais',
    help: 'A data aparece no calendário junto com os demais marcos.',
  },
  {
    id: 'progresso',
    name: 'Avanço físico medido (%)',
    type: 'number',
    group: 'Acompanhamento',
    help: 'Percentual medido e informado pela equipe. Não é calculado a partir da macroetapa.',
  },
  {
    id: 'duracao_dias',
    name: 'Duração prevista da execução (dias)',
    type: 'number',
    group: 'Prazos e marcos',
    help: 'Duração em dias. Este campo não representa uma data do calendário.',
  },
];

const templateDefinitions = {
  obras: {
    name: 'Obras prioritárias',
    audience: 'Carteira da Secretaria',
    tag: 'Prioridades e entregas',
    icon: 'folder',
    color: '#003856',
    bi: 'obras',
    description:
      'Consolide obras de vários órgãos, identifique gargalos e conduza a reunião de gestão.',
    question: 'Quais obras precisam de decisão da Secretaria nesta semana?',
    decisions: [
      'Definir a próxima providência e quem deve agir.',
      'Destravar as iniciativas de maior prioridade.',
      'Acompanhar as entregas por órgão e região.',
    ],
    groups: [
      'Essenciais',
      'Localização',
      'Prazos e marcos',
      'Financeiro',
      'Recursos e instrumentos',
      'Acompanhamento',
    ],
    keys: null,
    kpis: [
      'Carteira por órgão e macroetapa',
      'Prioridades altas e obras paralisadas',
      'Prazos vencidos e próximas entregas',
      'Investimento previsto, captado e executado',
      'Registros sem atualização',
    ],
    tabs: [
      'Visão geral',
      'Pipeline',
      'Prioridades',
      'Prazos',
      'Território',
      'Financeiro',
      'Detalhamento',
      'Qualidade',
    ],
    note: 'Abrange as 55 colunas da aba PIPELINE e adiciona campos de ação, responsável e medição física. A classificação de origem e a previsão de execução exigem validação antes do uso.',
  },
  link_externo: {
    name: 'Link Externo / Página',
    tag: 'Redirecionamento',
    icon: 'link', // ou o nome do ícone svg cadastrado no seu sistema
    color: '#0066cc',
    audience: 'Acesso Rápido',
    description:
      'Acesse uma página externa, dashboard do PowerBI ou documento diretamente ao clicar no projeto.',
    question: 'Como integrar sistemas e páginas externas ao portal?',
    tabs: ['Link Externo'],
    isLink: true,
  },
  contratacao: {
    name: 'Preparação e contratação',
    audience: 'Equipe de projetos e licitação',
    tag: 'Documentos e pendências',
    icon: 'file',
    color: '#846bb1',
    bi: 'obras',
    description:
      'Acompanhe projetos, orçamento, ETP, TR, jurídico e licitação com as pendências de cada etapa.',
    question: 'O que falta para esta iniciativa chegar à contratação?',
    decisions: [
      'Identificar o documento ou parecer que está pendente.',
      'Direcionar a cobrança à pessoa responsável.',
      'Definir o prazo para liberar a próxima etapa.',
    ],
    keys: [
      'codigo',
      'nome',
      'orgao',
      'tipo',
      'sei',
      'etapa',
      'status',
      'prioridade',
      'regiao',
      'bairro',
      'tem_projeto',
      'valor_projeto',
      'valor',
      'inicio',
      'prev_planejamento',
      'prev_preparatorio',
      'prev_contratacao',
      'prazo',
      'observacao',
      'atualizado_por',
      'atualizado_em',
    ],
    additional: [
      ...[
        'Projeto técnico',
        'Orçamento',
        'ETP',
        'TR',
        'Matriz de riscos',
        'Parecer jurídico',
        'Licitação',
      ].map((n, i) => ({
        id: 'doc_' + i,
        name: n,
        type: 'select',
        options: ['Não iniciado', 'Em elaboração', 'Em revisão', 'Concluído', 'Não se aplica'],
        group: 'Documentação',
        help: 'Informe a situação do documento ou da etapa; concluído deve corresponder à validação da equipe.',
      })),
      { id: 'pendencia', name: 'Pendência que impede o avanço', type: 'long', group: 'Essenciais' },
    ],
    kpis: [
      'Iniciativas por etapa',
      'Documentos pendentes por tipo',
      'Itens sem parecer jurídico',
      'Prazos de contratação',
      'Ações por responsável',
    ],
    tabs: [
      'Visão geral',
      'Pipeline',
      'Documentação',
      'Prioridades',
      'Prazos',
      'Detalhamento',
      'Qualidade',
    ],
    note: 'O preenchimento de documentos é um apoio gerencial. As exigências aplicáveis a cada contratação devem ser confirmadas pela equipe responsável.',
  },
  fisicofin: {
    name: 'Execução físico-financeira',
    audience: 'Gestor e fiscalização',
    tag: 'Medição e investimento',
    icon: 'chart',
    color: '#169dc4',
    bi: 'fisicofin',
    description:
      'Compare avanço físico medido, investimento e execução financeira, com a programação por exercício.',
    question: 'O avanço físico e a aplicação dos recursos estão acompanhando a execução?',
    decisions: [
      'Conferir medições e valores executados.',
      'Revisar os prazos e a programação financeira.',
      'Acionar a fiscalização quando houver divergências.',
    ],
    keys: [
      'codigo',
      'nome',
      'orgao',
      'sei',
      'etapa',
      'status',
      'prioridade',
      'regiao',
      'bairro',
      'valor',
      'executado',
      'captado',
      'contrapartida',
      'valor_total',
      'total_2026',
      'total_2027',
      'total_2028',
      'fonte',
      'programa',
      'inicio',
      'prazo',
      'atualizado_em',
    ],
    additional: [
      { id: 'medicao_em', name: 'Data da última medição', type: 'date', group: 'Acompanhamento' },
      { id: 'fiscal', name: 'Fiscal responsável', type: 'text', group: 'Acompanhamento' },
      { id: 'contratado', name: 'Valor contratado', type: 'currency', group: 'Financeiro' },
      { id: 'pago', name: 'Valor pago', type: 'currency', group: 'Financeiro' },
    ],
    kpis: [
      'Avanço físico informado',
      'Executado sobre previsto',
      'Valor contratado e pago',
      'Saldo previsto por obra',
      'Programação por exercício',
    ],
    tabs: ['Visão geral', 'Financeiro', 'Prazos', 'Prioridades', 'Detalhamento', 'Qualidade'],
    note: 'Previsto, contratado, executado e pago são medidas distintas. As parcelas por exercício não devem ser somadas novamente ao total. Sem medição física, o percentual permanece sem informação.',
  },
  recursos: {
    name: 'Captação de recursos',
    audience: 'SECAP e articulação institucional',
    tag: 'Fontes e financiamento',
    icon: 'money',
    color: '#268c48',
    bi: 'recursos',
    description:
      'Organize iniciativas, fontes, programas, financiadores e valores captados em uma jornada de captação.',
    question:
      'Quais iniciativas estão prontas para buscar recursos e o que falta para a liberação?',
    decisions: [
      'Priorizar iniciativas com documentação e contrapartida definidas.',
      'Acompanhar o contato com a instituição financiadora.',
      'Agendar as próximas providências de contratação e liberação.',
    ],
    keys: [
      'codigo',
      'nome',
      'orgao',
      'tipo',
      'sei',
      'etapa',
      'status',
      'prioridade',
      'tem_projeto',
      'valor',
      'captado',
      'contrapartida',
      'fonte',
      'programa',
      'financiadora',
      'financiar',
      'inicio',
      'prazo',
      'observacao',
      'atualizado_em',
    ],
    additional: [
      { id: 'pleiteado', name: 'Valor pleiteado', type: 'currency', group: 'Financeiro' },
      { id: 'aprovado', name: 'Valor aprovado', type: 'currency', group: 'Financeiro' },
      { id: 'liberado', name: 'Valor liberado', type: 'currency', group: 'Financeiro' },
      {
        id: 'etapa_captacao',
        name: 'Etapa da captação',
        type: 'select',
        options: [
          'Preparação',
          'Proposta apresentada',
          'Em análise',
          'Aprovado',
          'Contratação',
          'Liberação',
          'Encerrado',
        ],
        group: 'Essenciais',
      },
      {
        id: 'contato_financiador',
        name: 'Referência na instituição',
        type: 'text',
        group: 'Recursos e instrumentos',
      },
    ],
    kpis: [
      'Pleiteado, aprovado e liberado',
      'Captação por fonte e programa',
      'Contrapartida municipal',
      'Etapas da captação',
      'Próximos contatos e prazos',
    ],
    tabs: [
      'Visão geral',
      'Pipeline',
      'Captação',
      'Financeiro',
      'Prioridades',
      'Prazos',
      'Detalhamento',
      'Qualidade',
    ],
    note: 'Recurso pleiteado, aprovado, captado e liberado não são intercambiáveis. Os indicadores devem mostrar cada medida com sua definição.',
  },
  termos: {
    name: 'Termos e compromissos',
    audience: 'Gestão de instrumentos',
    tag: 'Vigências e entregas',
    icon: 'file',
    color: '#c68b39',
    bi: 'termos',
    description:
      'Acompanhe instrumentos, obrigações, parceiros, vigências e entregas vinculadas às obras.',
    question: 'Quais compromissos precisam de providência para cumprir as obrigações no prazo?',
    decisions: [
      'Acionar o parceiro responsável por uma obrigação pendente.',
      'Revisar vigência e documentação.',
      'Relacionar cada instrumento às obras e entregas correspondentes.',
    ],
    keys: [
      'codigo',
      'nome',
      'orgao',
      'sei',
      'status',
      'etapa',
      'prioridade',
      'tem_termo',
      'numero_termo',
      'valor',
      'executado',
      'contrapartida',
      'fonte',
      'prazo',
      'observacao',
      'atualizado_em',
    ],
    additional: [
      {
        id: 'parceiro',
        name: 'Instituição parceira',
        type: 'text',
        group: 'Recursos e instrumentos',
      },
      {
        id: 'obrigacao',
        name: 'Obrigação ou entrega vinculada',
        type: 'long',
        group: 'Essenciais',
      },
      {
        id: 'prestacao_contas',
        name: 'Situação da prestação de contas',
        type: 'select',
        options: [
          'Não iniciada',
          'Em elaboração',
          'Em análise',
          'Aprovada',
          'Com pendência',
          'Não se aplica',
        ],
        group: 'Acompanhamento',
      },
    ],
    kpis: [
      'Instrumentos vinculados',
      'Vigências próximas e vencidas',
      'Entregas por situação',
      'Obrigações pendentes',
      'Valores dos termos sem duplicidade',
    ],
    tabs: [
      'Visão geral',
      'Termos vinculados',
      'Prioridades',
      'Prazos',
      'Financeiro',
      'Detalhamento',
      'Qualidade',
    ],
    note: 'Um instrumento pode se relacionar a várias obras. Seu valor deve ser contado uma única vez no conjunto dos termos. O cadastro do instrumento permanece na aba Termos de compromisso.',
  },
  iniciativas: {
    name: 'Projetos e serviços',
    audience: 'Projetos diversos da Prefeitura',
    tag: 'Modelo flexível',
    icon: 'dashboard',
    color: '#6a8195',
    bi: 'auto',
    description:
      'Organize ações, estudos, serviços e iniciativas que precisam de acompanhamento, mesmo sem uma obra física.',
    question: 'O que foi combinado, qual é a próxima entrega e quem precisa agir?',
    decisions: [
      'Acompanhar marcos e entregas da equipe.',
      'Distribuir as próximas ações entre responsáveis.',
      'Revisar escopo, prioridade e prazo.',
    ],
    keys: [
      'codigo',
      'nome',
      'orgao',
      'tipo',
      'sei',
      'etapa',
      'status',
      'prioridade',
      'inicio',
      'prazo',
      'valor',
      'executado',
      'observacao',
      'atualizado_em',
    ],
    additional: [
      { id: 'objetivo', name: 'Resultado esperado', type: 'long', group: 'Essenciais' },
      { id: 'entrega', name: 'Próxima entrega', type: 'text', group: 'Essenciais' },
      { id: 'publico', name: 'Público ou área atendida', type: 'text', group: 'Acompanhamento' },
    ],
    kpis: [
      'Entregas por situação',
      'Próximas ações',
      'Carga por responsável',
      'Prazos do projeto',
      'Indicadores personalizados',
    ],
    tabs: ['Visão geral', 'Pipeline', 'Prioridades', 'Prazos', 'Detalhamento', 'Qualidade'],
    note: 'Os indicadores vêm dos campos efetivamente preenchidos. Campos financeiros podem permanecer sem associação quando não se aplicarem ao projeto.',
  },
};

function templateFields(key) {
  const t = templateDefinitions[key];
  const all = t.keys ? sourceFieldCatalog.filter((f) => t.keys.includes(f.id)) : sourceFieldCatalog;
  const fields = structuredClone([...all, ...extraOperationalFields, ...(t.additional || [])]);
  const seen = new Set();
  const order = [
    'Essenciais',
    'Localização',
    'Documentação',
    'Prazos e marcos',
    'Financeiro',
    'Recursos e instrumentos',
    'Acompanhamento',
  ];

  return fields
    .filter((f) => !seen.has(f.id) && seen.add(f.id))
    .map((f) => {
      if (f.help?.startsWith('Origem de referência:')) f.help = '';
      return f;
    })
    .sort(
      (a, b) =>
        order.indexOf(a.group) - order.indexOf(b.group) ||
        (a.id === 'nome' ? -1 : b.id === 'nome' ? 1 : 0)
    );
}

const captureRouteWithBI = routeSnapshot;
routeSnapshot = function () {
  return { ...captureRouteWithBI(), templateLibraryView, selectedTemplate };
};

const restoreRouteWithBI = restoreRoute;
restoreRoute = function (r) {
  templateLibraryView = r.templateLibraryView || '';
  selectedTemplate = r.selectedTemplate || 'obras';
  restoreRouteWithBI(r);
};

const goWithBI = go;
go = function (t, id = '') {
  templateLibraryView = '';
  goWithBI(t, id);
};

const openBIWithTemplates = openBI;
openBI = function (id) {
  templateLibraryView = '';
  openBIWithTemplates(id);
};

function openTemplateLibrary(key = '') {
  routeTrail.push(routeSnapshot());
  tab = 'bi';
  projectId = '';
  biProject = '';
  templateLibraryView = key ? 'detail' : 'catalog';
  if (key) selectedTemplate = key;
  query = '';
  render();
  window.scrollTo(0, 0);
}

const biWithModels = bi;
bi = function () {
  if (templateLibraryView === 'catalog') return templateCatalog();
  if (templateLibraryView === 'detail') return templateDetail(selectedTemplate);
  return biWithModels();
};

const foldersWithModels = biFolderPage;
biFolderPage = function () {
  return foldersWithModels().replace(
    '<div class="actions">',
    `<div class="actions">${btn('Biblioteca de modelos', 'openTemplateLibrary()', 'dashboard', 'primary')}`
  );
};

function templateCatalog() {
  return (
    head(
      'MODELOS DE GESTÃO',
      'Biblioteca de modelos',
      'Comece pela decisão que precisa tomar. O modelo organiza os campos e o BI do projeto.',
      btn('Voltar aos painéis', 'templateLibraryView="";render()', 'arrow')
    ) +
    `<section class="template-intro">
      <div>
        <div class="eyebrow">DO REGISTRO À DECISÃO</div>
        <h2>O mesmo portal. Uma leitura para cada situação.</h2>
        <p>O servidor registra a informação uma vez. A equipe acompanha a próxima ação. A Secretaria enxerga os gargalos, os compromissos e as decisões que precisam de encaminhamento.</p>
      </div>
      <div class="template-intro-note">${icon('shield')}<span>Dados ausentes ficam visíveis.<br>Etapas, valores e datas mantêm seu significado.</span></div>
    </section>
    <div class="model-library">
      ${Object.entries(templateDefinitions)
        .filter(([, t]) => !t.isLink)
        .map(
          ([key, t]) => `
        <article class="model-card" style="--model-color:${t.color}">
          <div class="model-card-top"><span class="model-icon">${icon(t.icon)}</span><span class="badge">${t.tag}</span></div>
          <div class="eyebrow">${t.audience.toUpperCase()}</div>
          <h2>${t.name}</h2>
          <p>${t.description}</p>
          <div class="model-question">${t.question}</div>
          <div class="model-card-meta"><span>${templateFields(key).length} campos organizados</span><span>${t.tabs.length} áreas de análise</span></div>
          <div class="model-card-actions">
            ${btn('Conhecer o modelo', `openTemplateLibrary('${key}')`, 'arrow')}
            ${canManage() ? btn('Usar modelo', `newProjectFromTemplate('${key}')`, 'plus', 'primary') : ''}
          </div>
        </article>
      `
        )
        .join('')}
    </div>
    <div class="summary-strip" style="margin-top:25px">${icon('folder')}<p><strong>Obras de saúde, educação ou infraestrutura podem usar o mesmo modelo de gestão.</strong> O conteúdo muda por órgão, tipo, região e projeto. Uma nova estrutura é necessária quando muda a forma de acompanhar o trabalho: contratação, execução, captação ou compromisso.</p></div>`
  );
}

function templateDetail(key) {
  const t = templateDefinitions[key],
    fields = templateFields(key),
    groups = [...new Set(fields.map((f) => f.group || 'Outras informações'))];
  return (
    backLink('Voltar à biblioteca') +
    `<section class="bihero">
      <div>
        <div class="eyebrow">MODELO DE GESTÃO · ${t.audience.toUpperCase()}</div>
        <h1>${t.name}</h1>
        <p>${t.description}</p>
        <div class="hero-meta"><span>${icon('file')}${fields.length} campos em ${groups.length} grupos</span><span>${icon('chart')}${t.tabs.length} áreas de análise</span></div>
      </div>
      <div class="hero-actions">
        <span class="hero-emblem">${icon(t.icon)}</span>
        ${canManage() ? btn('Criar projeto com este modelo', `newProjectFromTemplate('${key}')`, 'plus', 'orange') : ''}
      </div>
    </section>
    <div class="summary-strip">${icon('eye')}<p><strong>${t.question}</strong><br>${t.decisions.join(' ')}</p></div>
    <div class="chart-grid">
      <section class="panel">
        <div class="panelhead"><h2>O que o gestor acompanha</h2></div>
        <div class="panelbody"><div class="model-checklist">${t.kpis.map((k) => `<div>${icon('chart')}<span>${k}</span></div>`).join('')}</div></div>
      </section>
      <section class="panel">
        <div class="panelhead"><h2>Como a análise se organiza</h2></div>
        <div class="panelbody">
          <div class="model-tab-list">${t.tabs.map((n, i) => `<span><b>${String(i + 1).padStart(2, '0')}</b>${n}</span>`).join('')}</div>
          <p class="metric-note" style="margin:20px 0 0">${t.note}</p>
        </div>
      </section>
    </div>
    <section class="panel">
      <div class="panelhead"><div><h2>Formulário organizado por assunto</h2><small>Os campos essenciais aparecem primeiro. O restante pode ser preenchido conforme a etapa do trabalho.</small></div></div>
      <div class="panelbody">
        ${groups
          .map(
            (g, i) => `
          <details class="schema-group" ${i === 0 ? 'open' : ''}>
            <summary><span>${g}</span><small>${fields.filter((f) => f.group === g).length} campos</small>${icon('down')}</summary>
            <div class="schema-fields">
              ${fields
                .filter((f) => f.group === g)
                .map(
                  (f) =>
                    `<div><span>${esc(f.name)}${f.required ? ' *' : ''}</span><small>${typeNames[f.type] || f.type}</small></div>`
                )
                .join('')}
            </div>
          </details>
        `
          )
          .join('')}
      </div>
    </section>
    <div class="model-guideline"><b>Comece com o necessário.</b> O nome da iniciativa, o órgão e o responsável são os campos obrigatórios de início. A equipe completa os demais grupos no momento adequado. O avanço físico exige medição; a etapa do projeto não determina um percentual.</div>`
  );
}

const editProjectBeforeTemplates = editProject;
editProject = function (id = '') {
  if (id) return editProjectBeforeTemplates(id);
  if (!canManage()) return;
  const choice = (onclick, color, ic, name, desc) =>
    `<button type="button" class="template-choice" onclick="${onclick}"><span class="model-icon" style="--model-color:${color}">${icon(ic)}</span><span><b>${name}</b><small>${desc}</small></span>${icon('arrow')}</button>`;
  const models = Object.entries(templateDefinitions).filter(([, t]) => !t.isLink);
  modal(
    'Criar um novo projeto',
    `<p class="subtitle">Comece do zero, use um modelo pronto ou crie um card que abre um link externo.</p>
    <div class="project-template-picker">
      ${choice('newBlankProject()', '#315c75', 'plus', 'Começar do zero', 'Sem modelo. Você define o nome e cria os campos que quiser depois.')}
      ${choice("newProjectFromTemplate('link_externo')", '#0066cc', 'link', 'Link externo / página', 'Um card que abre uma página, dashboard ou documento em nova aba.')}
    </div>
    <p class="metric-note" style="margin:18px 0 0"><b>Ou escolha um modelo pronto</b></p>
    <div class="project-template-picker" style="margin-top:10px">
      ${models.map(([key, t]) => choice(`newProjectFromTemplate('${key}')`, t.color, t.icon, t.name, t.description)).join('')}
    </div>`,
    btn('Cancelar', 'closeModal()', 'close')
  );
};

function newBlankProject() {
  if (!canManage()) return;
  modal(
    'Novo projeto · Do zero',
    `<form id="blankProjectForm" onsubmit="event.preventDefault();saveBlankProject()">
      <div class="summary-strip" style="margin-bottom:22px">${icon('plus')}<p><strong>Projeto totalmente personalizável</strong><br>Defina os campos que cada obra/subprojeto deverá preencher. O campo Nome da obra será mantido como identificação obrigatória.</p></div>
      <div class="field"><label>Nome do projeto *</label><input name="name" required placeholder="Ex.: Revitalização de praças"></div>
      <div class="field"><label>Descrição</label><textarea name="description" rows="3" placeholder="Qual é o objetivo deste projeto?"></textarea></div>
      <div class="twocol">
        <div class="field"><label>Responsável *</label><input name="owner" required value="${esc(me().name)}"></div>
        <div class="field"><label>Cor de identificação</label><input name="color" type="color" value="#003856" style="height:43px"></div>
      </div>
      <div class="panel" style="padding:16px;margin-top:18px">
        <div class="panelhead"><div><h3>Campos de cada obra/subprojeto</h3><small>Adicione os dados que deverão ser preenchidos em cada registro. Você poderá alterá-los depois.</small></div></div>
        <div id="blankCustomFields"></div>
        <button class="btn secondary" type="button" onclick="addBlankProjectField()">${icon('plus')} Adicionar campo personalizado</button>
      </div>
    </form>`,
    btn('Voltar', 'editProject()', 'arrow') +
      `<button class="btn primary" form="blankProjectForm" type="submit">${icon('check')} Criar projeto</button>`
  );
}

let blankProjectFieldCounter = 0;

function addBlankProjectField() {
  const host = $('#blankCustomFields');
  if (!host) return;
  const key = `blank_${++blankProjectFieldCounter}`;
  host.insertAdjacentHTML('beforeend', `<div class="fieldrow blank-field-row" data-field-key="${key}" style="display:block;padding:12px 0;border-bottom:1px solid var(--line,#e5e7eb)">
    <div class="twocol"><div class="field"><label>Nome do campo *</label><input data-custom-name required placeholder="Ex.: Número do contrato"></div>
    <div class="field"><label>Tipo de informação</label><select data-custom-type onchange="this.closest('.blank-field-row').querySelector('[data-custom-options]').style.display=this.value==='select'?'block':'none'">${Object.entries(typeNames).map(([k,v])=>`<option value="${k}">${v}</option>`).join('')}</select></div></div>
    <div class="field" data-custom-options style="display:none"><label>Opções (separadas por vírgula)</label><input data-custom-list placeholder="Planejamento, Em execução, Concluída"></div>
    <div class="twocol"><div class="field"><label>Orientação de preenchimento</label><input data-custom-help placeholder="Explique o que deve ser informado"></div><label style="align-self:center"><input data-custom-required type="checkbox"> Obrigatório</label></div>
    <button class="btn danger small" type="button" onclick="this.closest('.blank-field-row').remove()">${icon('trash')} Remover campo</button>
  </div>`);
}

function saveBlankProject() {
  if (!canManage()) return;
  const form = $('#blankProjectForm');
  if (!form) return;
  const d = new FormData(form);
  const name = String(d.get('name') || '').trim();
  const owner = String(d.get('owner') || '').trim() || me().name;
  if (!name) return;
  const fields = [{ id: 'nome', name: 'Nome da obra', type: 'text', required: true }];
  const customRows = [...form.querySelectorAll('.blank-field-row')];
  for (const row of customRows) {
    const fieldName = row.querySelector('[data-custom-name]').value.trim();
    const type = row.querySelector('[data-custom-type]').value;
    const options = (row.querySelector('[data-custom-list]')?.value || '').split(',').map(x => x.trim()).filter(Boolean);
    if (!fieldName) return notify('Informe o nome de todos os campos personalizados.');
    if (type === 'select' && !options.length) return notify(`Informe as opções do campo "${fieldName}".`);
    fields.push({ id: 'f_' + uid(), name: fieldName, type, options: type === 'select' ? [...new Set(options)] : undefined, help: row.querySelector('[data-custom-help]').value.trim(), required: row.querySelector('[data-custom-required]').checked });
  }
  const p = {
    id: uid(),
    name,
    description: String(d.get('description') || '').trim(),
    owner,
    color: String(d.get('color') || '#003856'),
    externalUrl: '',
    isExternal: false,
    fields,
    records: [],
  };
  db.projects.push(p);
  persist('Criou projeto do zero', p, '', name);
  closeModal();
  go('projects', p.id);
  notify(`Projeto criado com ${Math.max(0, p.fields.length - 1)} campo(s) personalizado(s). Cada obra poderá preencher esses dados.`);
}

function newProjectFromTemplate(key) {
  if (key === 'link_externo') {
    openExternalLinkModal();
    return;
  }
  if (!canManage()) return;
  const t = templateDefinitions[key];
  modal(
    'Novo projeto · ' + t.name,
    `<form id="guidedProjectForm" onsubmit="event.preventDefault();saveGuidedProject('${key}')"><div class="summary-strip" style="margin-bottom:22px">${icon(t.icon)}<p>Modelo <strong>${t.name}</strong><br>${templateFields(key).length} campos agrupados e BI associado ao projeto.</p></div><div class="field"><label>Nome da pasta de projeto *</label><input aria-label="Nome da pasta de projeto" name="name" required placeholder="Ex.: Obras prioritárias — SEINFRA"></div><div class="field"><label>Objetivo ou descrição</label><textarea name="description" rows="3" placeholder="Qual resultado esta carteira de projetos precisa entregar?"></textarea></div><div class="twocol"><div class="field"><label>Responsável pela pasta *</label><input name="owner" required value="${esc(me().name)}"></div><div class="field"><label>Cor da pasta</label><input name="color" type="color" value="${t.color}" style="height:43px"></div></div><p class="metric-note" style="margin:0">A pasta será criada vazia. As linhas da planilha não são importadas automaticamente. Você poderá cadastrar os registros e personalizar o modelo.</p></form>`,
    btn('Escolher outro modelo', 'editProject()', 'arrow') +
      `<button class="btn primary" form="guidedProjectForm" type="submit">Criar pasta e painel</button>`
  );
}

function saveGuidedProject(key) {
  if (!canManage()) return;
  const t = templateDefinitions[key],
    d = new FormData($('#guidedProjectForm')),
    p = {
      id: uid(),
      name: String(d.get('name')).trim(),
      description: String(d.get('description')).trim(),
      owner: String(d.get('owner')).trim(),
      color: d.get('color'),
      fields: templateFields(key),
      records: [],
      biTemplate: t.bi,
      managementTemplate: key,
      entityKind:t.entityKind||'work',
      biMapping: {
        status: 'status',
        stage: key === 'recursos' ? 'etapa_captacao' : 'etapa',
        budget: 'valor',
        spent: 'executado',
        raised: 'captado',
        deadline: 'prazo',
        progress: 'progresso',
        owner: 'responsavel',
        agency: 'orgao',
        priority: 'prioridade',
        source: 'fonte',
      },
    };
  if (!p.name || !p.owner) return;
  db.projects.push(p);
  persist('Criou projeto a partir de modelo', p, '', t.name);
  closeModal();
  templateLibraryView = '';
  go('projects', p.id);
  notify('Pasta criada com campos organizados e BI conectado.');
}

// Substituição da função editRecord para abrir em Tela Cheia Real
editRecord = function (pid, rid = '') {
  const p = visible().find((p) => p.id === pid);
  if (!p) return;
  const r = p.records.find((r) => r.id === rid);
  const edit = canEdit(p);

  // Se for nova obra (sem registo), abre o formulário de inserção
  if (!r) {
    openRecordForm(pid, rid);
    return;
  }

  // Garante que não ficam visões anteriores abertas
  closeFullscreenDetail();

  const fields = p.fields;
  const groups = [...new Set(fields.map((f) => f.group || 'Outras informações'))].sort((a, b) =>
    a === 'Essenciais' ? -1 : b === 'Essenciais' ? 1 : 0
  );

  // Cria a estrutura em Tela Cheia anexada diretamente ao body
  const detailContainer = document.createElement('div');
  detailContainer.id = 'fullscreenDetailView';
  detailContainer.className = 'fullscreen-detail-page';

  detailContainer.innerHTML = `
    <header class="fullscreen-header">
      <div style="display:flex; align-items:center; gap:16px;">
        <button class="btn" type="button" onclick="closeFullscreenDetail()">${icon('arrow')} Voltar às obras</button>
        <div>
          <span class="eyebrow">${esc(p.name)}</span>
          <h1 style="margin:0; font-size:20px; color:#0f172a; font-weight:700;">${esc(r.nome || Object.values(r)[1] || 'Registro')}</h1>
        </div>
      </div>
      <div class="actions" style="display:flex; gap:10px;">
        ${edit ? `<button class="btn primary" type="button" onclick="closeFullscreenDetail(); openRecordForm('${pid}','${rid}')">${icon('edit')} Editar dados</button>` : ''}
        <button class="iconbtn" type="button" onclick="closeFullscreenDetail()" title="Fechar">${icon('close')}</button>
      </div>
    </header>

    <div class="fullscreen-content">
      <!-- Indicadores principais -->
      <div class="stats" style="margin-bottom: 24px;">
        <div class="stat">
          <div class="top">SITUAÇÃO</div>
          <div class="number" style="font-size:16px;">${badge(r.status)}</div>
        </div>
        <div class="stat">
          <div class="top">AVANÇO FÍSICO</div>
          <div class="number">${r.progresso !== '' && r.progresso != null ? r.progresso + '%' : '—'}</div>
        </div>
        <div class="stat">
          <div class="top">INVESTIMENTO</div>
          <div class="number">${r.valor !== '' && r.valor != null ? money(r.valor) : '—'}</div>
        </div>
        <div class="stat">
          <div class="top">PRAZO DE ENTREGA</div>
          <div class="number" style="font-size:16px;">${date(r.prazo)}</div>
        </div>
      </div>

     <!-- Exibição de todos os campos organizados por grupo com ícone e linha laranja -->
      ${groups
        .map((g) => {
          const groupFields = fields.filter((f) => (f.group || 'Outras informações') === g);
          return `
          <div class="section-group-header">
            <h2>${icon(getGroupIcon(g))} ${esc(g)}</h2>
            <span class="count-badge">${groupFields.length} campos</span>
          </div>
          <div class="detail-grid">
            ${groupFields
              .map((f) => {
                const val = r[f.id];
                let displayVal = esc(val ?? '—');
                if (f.type === 'date') displayVal = date(val);
                if (f.type === 'currency')
                  displayVal = val !== '' && val != null ? money(val) : '—';

                return `
                <div class="detail-card">
                  <label>${esc(f.name)}</label>
                  <div class="val">${displayVal || '—'}</div>
                </div>
              `;
              })
              .join('')}
          </div>
        `;
        })
        .join('')}
    </div>
  `;

  document.body.appendChild(detailContainer);
};
// Mapeamento de ícones por nome de grupo/assunto
function getGroupIcon(groupName) {
  const icons = {
    Essenciais: 'star',
    Localização: 'map-pin',
    'Prazos e marcos': 'calendar',
    Financeiro: 'dollar-sign',
    'Recursos e instrumentos': 'briefcase',
    Acompanhamento: 'activity',
    Documentação: 'file-text',
  };
  return icons[groupName] || 'folder';
}

function openRecordForm(pid, rid = '') {
  const p = visible().find((project) => project.id === pid);
  if (!p) return;

  const r = (p.records || []).find((record) => record.id === rid);
  const edit = canEdit(p);
  const groups = [...new Set((p.fields || []).map((field) => field.group || 'Outras informações'))]
    .sort((a, b) => (a === 'Essenciais' ? -1 : b === 'Essenciais' ? 1 : 0));

  const fieldMarkup = groups.length
    ? groups.map((group, index) => {
        const fields = p.fields.filter((field) => (field.group || 'Outras informações') === group);
        return `
          <section class="edit-section-group">
            ${group !== 'Essenciais' ? `<h3 class="edit-section-title">${esc(group)}</h3>` : ''}
            <div class="edit-cards-grid">
              ${fields.map((field) => inputField(field, r?.[field.id], !edit)).join('')}
            </div>
          </section>`;
      }).join('')
    : '<p class="subtitle">Este projeto ainda não possui campos cadastrados.</p>';

  modal(
    r ? 'Editar obra / subprojeto' : 'Cadastrar obra / subprojeto',
    `<div class="record-form-intro">
       <p class="subtitle">${esc(p.name)}</p>
       <p class="metric-note">Preencha os mesmos campos e tipos de informação disponíveis no cadastro. Os valores atuais foram carregados para edição.</p>
     </div>
     <form id="recordForm" onsubmit="event.preventDefault();saveRecord('${pid}','${rid}')" style="padding-top:10px;">
       ${fieldMarkup}
     </form>`,
    (edit && r ? btn('Excluir', `deleteRecord('${pid}','${rid}')`, 'trash') : '') +
      btn('Cancelar', r ? `editRecord('${pid}','${rid}')` : 'closeModal()', 'arrow') +
      (edit
        ? `<button class="btn primary" form="recordForm" type="submit">${icon('check')} ${r ? 'Salvar alterações' : 'Cadastrar obra'}</button>`
        : '')
  );
}

// Qualidade e funções analíticas do BI
function projectQuality(p, rs) {
  const issues = [],
    codes = new Map();
  for (const r of rs) {
    const title = recordTitle(r, p),
      key = String(r.codigo || '').trim();
    if (key) {
      if (!codes.has(key)) codes.set(key, []);
      codes.get(key).push(r);
    }
    const add = (level, field, reason, action) =>
      issues.push({ r, title, level, field, reason, action });
    for (const f of p.fields) {
      if (f.required && (r[f.id] == null || String(r[f.id]).trim() === ''))
        add(
          'Completar',
          f.name,
          'Campo obrigatório sem preenchimento.',
          'Preencher o campo na ficha.'
        );
      if (f.type === 'date' && r[f.id]) {
        const d = String(r[f.id]);
        if (!/^\d{4}-\d{2}-\d{2}$/.test(d) || d < '2000-01-01' || d > '2099-12-31')
          add(
            'Revisar',
            f.name,
            'Valor fora do padrão de data esperado.',
            'Conferir a data e a unidade na origem.'
          );
      }
      if (
        ['number', 'currency'].includes(f.type) &&
        r[f.id] !== '' &&
        r[f.id] != null &&
        !Number.isFinite(Number(r[f.id]))
      )
        add(
          'Revisar',
          f.name,
          'Valor não numérico em campo de número ou moeda.',
          'Revisar o valor informado.'
        );
      if (f.type === 'select' && r[f.id] && !f.options?.includes(r[f.id]))
        add(
          'Revisar',
          f.name,
          'Valor não previsto na lista configurada.',
          'Padronizar a opção ou ajustar o campo.'
        );
    }
    if (p.fields.some((f) => f.id === 'prazo') && !r.prazo && !isFinished(r, p))
      add(
        'Completar',
        'Prazo de encerramento',
        'Registro não concluído sem data de referência.',
        'Definir o prazo ou justificar a ausência.'
      );
    if (r.execucao_origem)
      add(
        'Revisar',
        'Previsão de execução — origem',
        'O conteúdo de origem pode representar uma duração.',
        'Confirmar a unidade e preencher a duração em dias ou o marco de data correto.'
      );
    if (r.atualizado_em && daysLeft(r.atualizado_em) < -30)
      add(
        'Atualizar',
        'Data da última atualização',
        'A data informada é anterior a 30 dias.',
        'Solicitar confirmação do andamento à equipe.'
      );
    if (
      numberOrNull(r.progresso) !== null &&
      (Number(r.progresso) < 0 || Number(r.progresso) > 100)
    )
      add(
        'Revisar',
        'Avanço físico',
        'Percentual fora do intervalo de 0 a 100.',
        'Conferir a medição informada.'
      );
  }
  for (const [code, rows] of codes) {
    if (rows.length > 1)
      rows.forEach((r) =>
        issues.push({
          r,
          title: recordTitle(r, p),
          level: 'Reconciliar',
          field: 'ID de origem',
          reason: `O código ${code} aparece em ${rows.length} registros desta seleção.`,
          action:
            'Comparar as versões e confirmar a chave com a equipe. Nenhuma linha é excluída automaticamente.',
        })
      );
  }
  return issues;
}

function biQuality(p, rs) {
  const issues = projectQuality(p, rs),
    affected = new Set(issues.map((i) => i.r.id)),
    dups = new Set(issues.filter((i) => i.level === 'Reconciliar').map((i) => i.r.codigo));
  return `<div class="stats">${biMetric('REGISTROS ANALISADOS', rs.length, 'Respeita os filtros do projeto', 'file')}${biMetric('REGISTROS COM PENDÊNCIA', affected.size, 'Uma iniciativa pode ter mais de uma pendência', 'alert', '#f37021')}${biMetric('CÓDIGOS REPETIDOS', dups.size, 'Chaves de origem para reconciliar', 'shield', '#c93636')}${biMetric('PONTOS PARA CONFERIR', issues.length, 'Campos obrigatórios, datas e padronização', 'edit', '#169dc4')}</div>
    <div class="summary-strip">${icon('shield')}<p><strong>Conferir antes de consolidar.</strong> Identificadores repetidos precisam ser reconciliados; valores ausentes não são estimados; duração e data têm campos separados. A conferência observa os dados da seleção atual e preserva todos os registros.</p></div>
    <section class="panel">
      <div class="panelhead"><div><h2>O que precisa ser conferido</h2><small>A próxima ação é sempre indicada ao lado da pendência.</small></div></div>
      <div class="tablewrap">
        <table>
          <thead><tr><th>Iniciativa</th><th>Tipo</th><th>Campo</th><th>O que foi encontrado</th><th>Como resolver</th></tr></thead>
          <tbody>${issues.map((i) => `<tr><td style="white-space:normal;min-width:200px"><button class="project-link" onclick="editRecord('${p.id}','${i.r.id}')">${esc(i.title)}</button></td><td><span class="badge ${i.level === 'Reconciliar' ? 'red' : 'orange'}">${i.level}</span></td><td style="white-space:normal">${esc(i.field)}</td><td style="white-space:normal;min-width:210px">${esc(i.reason)}</td><td style="white-space:normal;min-width:230px">${esc(i.action)}</td></tr>`).join('')}</tbody>
        </table>
      </div>
      ${issues.length ? '' : empty('Nenhuma pendência detectada pelas regras atuais', 'A validação do conteúdo continua sob responsabilidade da equipe.')}
    </section>
    ${qualityPanel(p, rs)}`;
}

if (!biSections.some((s) => s[0] === 'quality'))
  biSections.splice(biSections.length - 1, 0, ['quality', 'Qualidade', 'shield']);

function biDocuments(p, rs) {
  const fs = p.fields.filter((f) => f.id.startsWith('doc_'));
  if (!fs.length)
    return empty(
      'Sem campos de documentação',
      'O modelo de preparação e contratação inclui as etapas documentais.'
    );
  const pending = (r, f) => !['Concluído', 'Não se aplica'].includes(r[f.id]);
  return `<div class="stats" style="grid-template-columns:repeat(3,1fr)">${biMetric('INICIATIVAS NA ANÁLISE', rs.length, 'Projetos e contratações', 'folder')}${biMetric('COM DOCUMENTO PENDENTE', rs.filter((r) => fs.some((f) => pending(r, f))).length, 'Inclui situações ainda não informadas', 'file', '#f37021')}${biMetric('DOCUMENTAÇÃO INFORMADA', rs.filter((r) => fs.every((f) => !pending(r, f))).length, 'Todos os itens concluídos ou não aplicáveis', 'check', '#268c48')}</div>
    <div class="summary-strip">${icon('file')}<p><strong>Qual documento está impedindo o avanço?</strong> A matriz organiza as etapas documentais por iniciativa. A validação da documentação e dos requisitos de contratação cabe à equipe responsável.</p></div>
    <section class="panel">
      <div class="panelhead"><h2>Matriz de preparação para contratação</h2></div>
      <div class="tablewrap">
        <table>
          <thead><tr><th>Iniciativa</th>${fs.map((f) => `<th>${esc(f.name)}</th>`).join('')}<th>Responsável</th></tr></thead>
          <tbody>${rs.map((r) => `<tr><td><button class="project-link" onclick="editRecord('${p.id}','${r.id}')">${esc(recordTitle(r, p))}</button></td>${fs.map((f) => `<td><span class="badge ${r[f.id] === 'Concluído' ? 'green' : r[f.id] === 'Não se aplica' ? 'gray' : 'orange'}">${esc(r[f.id] || 'Não informado')}</span></td>`).join('')}<td>${esc(r.responsavel || 'Definir responsável')}</td></tr>`).join('')}</tbody>
        </table>
      </div>
      ${rs.length ? '' : empty('Nenhum registro cadastrado', 'Cadastre a iniciativa e informe a situação dos documentos.')}
    </section>
    <div class="chart-grid" style="margin-top:23px">${fs.map((f) => chartPanel(esc(f.name), 'Situação informada pela equipe', groupsChart(p, rs, f))).join('')}</div>`;
}

function biTerritory(p, rs) {
  const region = p.fields.find((f) => f.id === 'regiao'),
    district = p.fields.find((f) => f.id === 'bairro');
  return `<div class="summary-strip">${icon('folder')}<p><strong>Onde estão as entregas?</strong> Organize a carteira por região e bairro e confira os investimentos associados. Este painel usa as localidades cadastradas; nenhuma coordenada ou localização é estimada.</p></div>
    <div class="chart-grid">${chartPanel('Carteira por região', 'Quantidade de iniciativas', groupsChart(p, rs, region))}${chartPanel('Investimento por região', 'Valores previstos da carteira', groupsChart(p, rs, region, 'money'))}</div>
    ${chartPanel('Detalhamento territorial', 'Clique na iniciativa para conferir a ficha', `<div class="tablewrap"><table><thead><tr><th>Iniciativa</th><th>Órgão</th><th>Região</th><th>Bairro</th><th>Prioridade</th><th>Previsto</th></tr></thead><tbody>${rs.map((r) => `<tr><td style="white-space:normal;min-width:220px"><button class="project-link" onclick="editRecord('${p.id}','${r.id}')">${esc(recordTitle(r, p))}</button></td><td>${esc(r.orgao || '—')}</td><td>${esc(r[region?.id] || 'Não informado')}</td><td>${esc(r[district?.id] || 'Não informado')}</td><td>${esc(r.prioridade || 'Não informada')}</td><td>${numberOrNull(r.valor) === null ? '—' : compact(r.valor)}</td></tr>`).join('')}</tbody></table></div>`)}
    <p class="metric-note" style="margin-top:18px">A abrangência territorial não permite inferir população atendida. Esse indicador exige fonte e metodologia próprias.</p>`;
}

function directTotal(rs, key) {
  const vs = rs.map((r) => numberOrNull(r[key])).filter((n) => n !== null);
  return vs.length ? vs.reduce((a, b) => a + b, 0) : null;
}

function biFunding(p, rs) {
  const pleit = directTotal(rs, 'pleiteado'),
    approved = directTotal(rs, 'aprovado'),
    released = directTotal(rs, 'liberado'),
    counter = directTotal(rs, 'contrapartida');
  return `<div class="stats">${biMetric('VALOR PLEITEADO', semanticMoney(pleit), 'Propostas apresentadas', 'money')}${biMetric('VALOR APROVADO', semanticMoney(approved), 'Decisões de aprovação informadas', 'check', '#268c48')}${biMetric('VALOR LIBERADO', semanticMoney(released), 'Recursos efetivamente liberados', 'money', '#169dc4')}${biMetric('CONTRAPARTIDA MUNICIPAL', semanticMoney(counter), 'Compromisso informado do Município', 'money', '#f37021')}</div>
    <div class="summary-strip">${icon('money')}<p><strong>Da proposta à liberação.</strong> Acompanhe cada medida separadamente. A diferença entre pleiteado, aprovado e liberado depende da correspondência e do preenchimento de cada iniciativa; valores em branco não representam zero.</p></div>
    <div class="chart-grid">${chartPanel(
      'Jornada de captação',
      'Etapa atual de cada iniciativa',
      groupsChart(
        p,
        rs,
        p.fields.find((f) => f.id === 'etapa_captacao')
      )
    )}${chartPanel(
      'Instituições financiadoras',
      'Iniciativas por instituição',
      groupsChart(
        p,
        rs,
        p.fields.find((f) => f.id === 'financiadora')
      )
    )}</div>
    ${chartPanel('Painel das iniciativas de captação', 'Responsáveis, programas e valores na mesma leitura', `<div class="tablewrap"><table><thead><tr><th>Iniciativa</th><th>Fonte / programa</th><th>Etapa</th><th>Pleiteado</th><th>Aprovado</th><th>Liberado</th><th>Próxima ação</th></tr></thead><tbody>${rs.map((r) => `<tr><td><button class="project-link" onclick="editRecord('${p.id}','${r.id}')">${esc(recordTitle(r, p))}</button></td><td>${esc(r.fonte || '—')}<div class="desc">${esc(r.programa || '')}</div></td><td>${esc(r.etapa_captacao || 'Não informada')}</td>${['pleiteado', 'aprovado', 'liberado'].map((k) => `<td>${numberOrNull(r[k]) === null ? '—' : money(r[k])}</td>`).join('')}<td style="white-space:normal;min-width:220px">${esc(r.proxima || 'Definir providência')}<div class="desc">${esc(r.responsavel || 'Sem responsável')}</div></td></tr>`).join('')}</tbody></table></div>`)}`;
}

const biFinanceBase = biFinance;
biFinance = function (p, rs) {
  let html = biFinanceBase(p, rs);
  const years = p.fields.filter((f) => /^total_\d{4}$/.test(f.id));
  if (years.length)
    html += `<section class="panel" style="margin-top:23px"><div class="panelhead"><div><h2>Programação financeira por exercício</h2><small>Subtotais anuais informados · visão de planejamento</small></div></div><div class="tablewrap annual-table"><table><thead><tr><th>Iniciativa</th>${years.map((f) => `<th>${f.id.slice(6)}</th>`).join('')}</tr></thead><tbody>${rs.map((r) => `<tr><td><button class="project-link" onclick="editRecord('${p.id}','${r.id}')">${esc(recordTitle(r, p))}</button></td>${years.map((f) => `<td>${numberOrNull(r[f.id]) === null ? '—' : money(r[f.id])}</td>`).join('')}</tr>`).join('')}<tr><td><strong>Subtotal por exercício</strong></td>${years.map((f) => `<td><strong>${semanticMoney(directTotal(rs, f.id))}</strong></td>`).join('')}</tr></tbody></table></div><div class="insight-footer">A programação anual já compõe os valores do projeto. Não deve ser adicionada novamente aos totais. Não representa uma série histórica de execução.</div></section>`;
  const extras = p.fields.filter((f) => ['contratado', 'pago'].includes(f.id));
  if (extras.length)
    html += `<div class="stats" style="margin-top:23px;grid-template-columns:repeat(2,1fr)">${extras.map((f) => biMetric(f.name.toUpperCase(), semanticMoney(directTotal(rs, f.id)), 'Medida informada separadamente', 'money')).join('')}</div>`;
  return html;
};

render();
