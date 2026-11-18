/* ============================================================================
   SECAP · DOWNLOAD DE RELATÓRIOS (somente administradores)
   Abas: Auditoria (registros de alteração) e Registro semanal.
   Usa as mesmas consultas já existentes (secap_audit_page e secap_weekly_log); não exige
   nenhuma migração nova no banco. Formatos: Excel (.xlsx) e CSV (.csv).
   ============================================================================ */

const REPORT_AUDIT_MAX_ROWS = 20000; // limite de segurança para uma única exportação
const REPORT_WEEKLY_MAX_PAGES = 20; // 20 consultas x 12 semanas = 240 semanas
const REPORT_CELL_LIMIT = 32000; // o Excel aceita no máximo 32.767 caracteres por célula
let reportExporting = false;

const reportTz = 'America/Sao_Paulo';

function reportText(value) {
  if (value === undefined || value === null || value === '') return '';
  const text = typeof value === 'object' ? JSON.stringify(value) : String(value);
  return text.length > REPORT_CELL_LIMIT ? text.slice(0, REPORT_CELL_LIMIT) + '… (truncado)' : text;
}

function reportDateTime(at) {
  const date = new Date(at);
  return Number.isNaN(date.getTime()) ? '' : date.toLocaleString('pt-BR', { timeZone: reportTz });
}

function reportIsoToBr(iso) {
  return /^\d{4}-\d{2}-\d{2}/.test(iso || '')
    ? iso.slice(0, 10).split('-').reverse().join('/')
    : '';
}

function reportStamp() {
  // AAAA-MM-DD no horário de Brasília
  return new Date().toLocaleDateString('sv-SE', { timeZone: reportTz });
}

function reportRole(role) {
  return role === 'administrador'
    ? 'Administrador'
    : role === 'usuario'
      ? 'Usuário'
      : 'Sem conta vinculada';
}

function reportCsv(headers, rows) {
  // Prefixa ' em textos iniciados por = + - @ para que o Excel não interprete como fórmula.
  const cell = (v) => {
    let t = String(v ?? '');
    if (/^[=+\-@\t\r]/.test(t) && !/^-?\d+([.,]\d+)?$/.test(t)) t = "'" + t;
    return '"' + t.replace(/"/g, '""') + '"';
  };
  return '\ufeff' + [headers, ...rows].map((row) => row.map(cell).join(';')).join('\r\n');
}

function reportSheet(headers, rows, widths) {
  const ws = XLSX.utils.aoa_to_sheet([headers, ...rows]);
  ws['!cols'] = (widths || headers.map(() => 22)).map((wch) => ({ wch }));
  if (rows.length)
    ws['!autofilter'] = {
      ref: XLSX.utils.encode_range({
        s: { r: 0, c: 0 },
        e: { r: rows.length, c: headers.length - 1 },
      }),
    };
  ws['!freeze'] = { xSplit: 0, ySplit: 1 };
  return ws;
}

function reportDownload(format, baseName, sheets) {
  // sheets: [{ name, headers, rows, widths }] — o CSV usa somente a primeira.
  if (format === 'csv') {
    const first = sheets[0];
    downloadBlob(reportCsv(first.headers, first.rows), `${baseName}.csv`, 'text/csv;charset=utf-8');
    return;
  }
  if (!window.XLSX)
    throw new Error('Biblioteca Excel indisponível. Escolha CSV ou recarregue a página.');
  const wb = XLSX.utils.book_new();
  sheets.forEach((s) =>
    XLSX.utils.book_append_sheet(wb, reportSheet(s.headers, s.rows, s.widths), s.name)
  );
  XLSX.writeFile(wb, `${baseName}.xlsx`);
}

/* ------------------------------- Diálogo -------------------------------- */

function openReportExport(kind) {
  if (!isSysAdmin()) return;
  const audit = kind === 'audit';
  if (audit ? auditLoading : weeklyLoading) return notify('Aguarde o carregamento terminar.');
  const scopeInfo = audit
    ? `<p class="subtitle">Serão baixados <b>todos os registros</b> do período e das datas atualmente selecionados na tela (${esc(
        auditView === 'archive' ? 'Histórico arquivado' : 'Registros recentes'
      )}${
        auditDateMode === 'selected' && auditStart && auditEnd
          ? `, de ${esc(reportIsoToBr(auditStart))} a ${esc(reportIsoToBr(auditEnd))}`
          : ''
      }), e não apenas a página exibida.</p>`
    : `<div class="field"><label>Período do relatório</label><select id="reportScope">
         <option value="shown">Semanas exibidas na tela${
           weeklyData
             ? ` (${esc(weeklyDate(weeklyData.oldestWeek))} a ${esc(weeklyDate(weeklyData.weeks?.[0]?.end))})`
             : ''
         }</option>
         <option value="all">Todo o histórico disponível</option>
       </select></div>`;
  modal(
    audit ? 'Baixar relatório de auditoria' : 'Baixar registro semanal',
    `${scopeInfo}<div class="field"><label>Formato do arquivo</label><select id="reportFormat">
       <option value="xlsx">Excel (.xlsx)${audit ? '' : ' — com resumo por semana'}</option>
       <option value="csv">CSV (.csv)</option></select></div>
     <p id="reportStatus" class="subtitle" role="status"></p>`,
    btn('Cancelar', 'closeModal()', 'close') +
      `<button class="btn primary" id="reportGo" type="button" onclick="runReportExport('${kind}')">${icon('download')} Baixar relatório</button>`
  );
}

async function runReportExport(kind) {
  if (reportExporting || !isSysAdmin()) return;
  const format = $('#reportFormat')?.value === 'csv' ? 'csv' : 'xlsx';
  const scope = $('#reportScope')?.value === 'all' ? 'all' : 'shown';
  const go = $('#reportGo');
  const status = $('#reportStatus');
  reportExporting = true;
  if (go) go.disabled = true;
  const say = (text) => {
    if (status) status.textContent = text;
  };
  try {
    if (!window.sb) throw new Error('Conexão ao servidor indisponível.');
    if (typeof saveChain !== 'undefined') await saveChain; // inclui alterações recém-salvas
    say('Reunindo os registros…');
    const result =
      kind === 'audit' ? await buildAuditReport(say) : await buildWeeklyReport(scope, say);
    if (!result.count) {
      say('Não há registros para exportar neste período.');
      return;
    }
    reportDownload(format, result.baseName, result.sheets);
    closeModal();
    notify(
      `Relatório gerado (${result.count} registro${result.count === 1 ? '' : 's'}).` +
        (result.truncated
          ? ` Limite de ${result.limit} atingido: refine o período para obter o restante.`
          : ''),
      result.truncated ? 'error' : ''
    );
  } catch (error) {
    say('Não foi possível gerar o relatório: ' + String(error?.message || error));
  } finally {
    reportExporting = false;
    if (go) go.disabled = false;
  }
}

/* -------------------------------- Auditoria ------------------------------ */

async function buildAuditReport(say) {
  const rows = [];
  let cursor = null;
  let truncated = false;
  for (;;) {
    const args = {
      p_view: auditView,
      p_start: auditDateMode === 'selected' ? auditStart : null,
      p_end: auditDateMode === 'selected' ? auditEnd : null,
      p_before_at: cursor?.at || null,
      p_before_id: cursor?.id || null,
      p_archive_end: auditView === 'archive' ? auditArchiveEnd || null : null,
    };
    const result = await window.sb.rpc('secap_audit_page', args);
    if (result.error) throw result.error;
    if (!Array.isArray(result.data?.rows)) throw new Error('Resposta de auditoria inválida.');
    rows.push(...result.data.rows);
    say(`Reunindo os registros… ${rows.length}`);
    if (!result.data.hasMore || !result.data.nextCursor) break;
    if (rows.length >= REPORT_AUDIT_MAX_ROWS) {
      truncated = true;
      break;
    }
    cursor = result.data.nextCursor;
  }
  const headers = [
    'Data e Hora',
    'Usuário/Responsável',
    'Ação',
    'Projeto',
    'Obra/Registro',
    'Campo',
    'Registro Anterior',
    'Registro Atualizado',
    'Justificativa',
    'Situação da recuperação',
  ];
  const body = rows.map((l) => {
    const project = db.projects.find((p) => p.id === l.project);
    const field = l.field || (l.action?.startsWith('Alterou ') ? l.action.slice(8) : '');
    const wholeRecord = l.eventId && !l.fieldId; // criação/exclusão guardam a obra inteira
    return [
      reportDateTime(l.at),
      l.who || 'Não informado',
      l.action || '',
      l.projectName || project?.name || (l.project ? l.where || l.project : ''),
      l.recordName || '',
      field,
      reportText(wholeRecord && l.before ? { 'Dados da obra': l.before } : l.before),
      reportText(wholeRecord && l.after ? { 'Dados da obra': l.after } : l.after),
      typeof auditReason === 'function' ? auditReason(l) : '',
      l.recovered
        ? 'Recuperado'
        : l.recoveredFrom
          ? `Recuperação do registro ${l.recoveredFrom}`
          : l.eventId && l.recoverable && l.fieldId
            ? 'Recuperável'
            : 'Indisponível',
    ];
  });
  const period =
    auditDateMode === 'selected' && auditStart && auditEnd
      ? `${reportIsoToBr(auditStart)} a ${reportIsoToBr(auditEnd)}`
      : `${reportIsoToBr(auditPeriodStart)} a ${reportIsoToBr(auditPeriodEnd)}`;
  return {
    count: body.length,
    truncated,
    limit: REPORT_AUDIT_MAX_ROWS,
    baseName: `secap-auditoria-${reportStamp()}`,
    sheets: [
      { name: 'Auditoria', headers, rows: body, widths: [20, 26, 24, 28, 30, 24, 40, 40, 40, 26] },
      {
        name: 'Informações',
        headers: ['Item', 'Valor'],
        rows: [
          ['Relatório', 'Registros de alteração (Auditoria)'],
          ['Consulta', auditView === 'archive' ? 'Histórico arquivado' : 'Registros recentes'],
          ['Período consultado', period],
          ['Total de registros', body.length],
          ['Gerado em', reportDateTime(new Date())],
          ['Gerado por', me()?.name || ''],
        ],
        widths: [24, 50],
      },
    ],
  };
}

/* ----------------------------- Registro semanal -------------------------- */

async function buildWeeklyReport(scope, say) {
  let weeks;
  let currentWeek = weeklyData?.currentWeek || '';
  if (scope === 'shown' && weeklyData) {
    weeks = weeklyData.weeks;
  } else {
    weeks = [];
    let anchor = null;
    for (let i = 0; i < REPORT_WEEKLY_MAX_PAGES; i++) {
      const result = await window.sb.rpc('secap_weekly_log', { p_week: anchor, p_weeks: 12 });
      if (result.error) throw result.error;
      if (!Array.isArray(result.data?.weeks)) throw new Error('Resposta inválida do servidor.');
      weeks.push(...result.data.weeks);
      currentWeek = result.data.currentWeek;
      say(`Reunindo as semanas… ${weeks.length}`);
      if (!result.data.hasOlder) break;
      const prev = new Date(`${result.data.oldestWeek}T12:00:00Z`);
      prev.setUTCDate(prev.getUTCDate() - 7);
      anchor = prev.toISOString().slice(0, 10);
    }
  }
  const changeHeaders = [
    'Semana (início)',
    'Semana (fim)',
    'Data e Hora',
    'Usuário',
    'Perfil',
    'Tipo',
    'Ação',
    'Projeto',
    'Obra / Local',
    'Campo',
    'Valor anterior',
    'Valor atualizado',
  ];
  const changes = [];
  const summary = [];
  const idle = [];
  for (const week of weeks) {
    const users = Array.isArray(week.users) ? week.users : [];
    const inactive = Array.isArray(week.inactive) ? week.inactive : [];
    summary.push([
      reportIsoToBr(week.start),
      reportIsoToBr(week.end),
      week.start === currentWeek ? 'Semana atual' : '',
      week.total || 0,
      week.records || 0,
      users.length,
      inactive.length,
    ]);
    inactive.forEach((u) =>
      idle.push([
        reportIsoToBr(week.start),
        reportIsoToBr(week.end),
        u.name || '',
        reportRole(u.role),
      ])
    );
    for (const user of users) {
      const who = user.name || 'Não informado';
      const role = user.identified ? reportRole(user.role) : 'Sem conta identificada';
      const base = [reportIsoToBr(week.start), reportIsoToBr(week.end)];
      for (const rec of user.records || []) {
        for (const c of rec.changes || []) {
          const fieldChange = c.field && c.field !== 'Obra';
          changes.push([
            ...base,
            reportDateTime(c.at),
            who,
            role,
            'Obra',
            c.action || 'Alteração',
            rec.project || '',
            rec.record || rec.recordId || '',
            fieldChange ? c.field : '',
            fieldChange ? reportText(c.before) : '',
            fieldChange ? reportText(c.after) : '',
          ]);
        }
      }
      for (const o of user.other || []) {
        changes.push([
          ...base,
          reportDateTime(o.at),
          who,
          role,
          'Configuração',
          o.action || 'Ação',
          '',
          o.where || 'Portal',
          '',
          reportText(o.before),
          reportText(o.after),
        ]);
      }
    }
  }
  // Mais recentes primeiro dentro de cada semana (as semanas já vêm da mais recente para a mais antiga).
  const toStamp = (row) => {
    const m = String(row[2]).match(/(\d{2})\/(\d{2})\/(\d{4}),? (\d{2}):(\d{2}):(\d{2})/);
    return m ? `${m[3]}${m[2]}${m[1]}${m[4]}${m[5]}${m[6]}` : '';
  };
  changes.sort((a, b) => toStamp(b).localeCompare(toStamp(a)));

  const oldest = weeks.length ? weeks[weeks.length - 1].start : '';
  const newest = weeks.length ? weeks[0].end : '';
  return {
    count: changes.length,
    baseName: `secap-registro-semanal-${reportStamp()}`,
    sheets: [
      {
        name: 'Alterações',
        headers: changeHeaders,
        rows: changes,
        widths: [14, 14, 20, 26, 20, 14, 24, 26, 30, 24, 40, 40],
      },
      {
        name: 'Resumo semanal',
        headers: [
          'Semana (início)',
          'Semana (fim)',
          'Observação',
          'Alterações',
          'Obras afetadas',
          'Pessoas que alteraram',
          'Pessoas sem alteração',
        ],
        rows: summary,
        widths: [16, 16, 16, 14, 16, 22, 22],
      },
      {
        name: 'Sem alterações',
        headers: ['Semana (início)', 'Semana (fim)', 'Usuário', 'Perfil'],
        rows: idle,
        widths: [16, 16, 32, 22],
      },
      {
        name: 'Informações',
        headers: ['Item', 'Valor'],
        rows: [
          ['Relatório', 'Registro semanal de alterações'],
          ['Período', `${reportIsoToBr(oldest)} a ${reportIsoToBr(newest)}`],
          ['Semanas incluídas', weeks.length],
          ['Total de alterações', changes.length],
          ['Gerado em', reportDateTime(new Date())],
          ['Gerado por', me()?.name || ''],
        ],
        widths: [24, 50],
      },
    ],
  };
}
