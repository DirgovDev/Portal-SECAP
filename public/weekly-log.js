/* ============================================================================
   SECAP · REGISTRO SEMANAL DE ALTERAÇÕES (somente administradores)
   Dados: RPC public.secap_weekly_log (supabase/migrations/20261117150000_registro_semanal.sql),
   que agrupa por semana (segunda a domingo, horário de Brasília) a auditoria do servidor
   (obras criadas, editadas e excluídas) e as ações de configuração do portal.
   Os registros são somente leitura: o portal não tem permissão para alterá-los.
   ============================================================================ */

const WEEKLY_PAGE_SIZE = 4;
let weeklyData = null,
  weeklyLoading = false,
  weeklyError = '',
  weeklyAnchor = null, // segunda-feira da semana mais recente exibida (null = semana atual)
  weeklyRequest = 0;

// Navegação: logo após "Auditoria", na área restrita ao administrador.
if (!navs.some((n) => n[0] === 'weekly')) {
  const at = navs.findIndex((n) => n[0] === 'history');
  navs.splice(at < 0 ? navs.length : at + 1, 0, ['weekly', 'Registro semanal', 'calendar']);
}

const pageBeforeWeekly = page;
page = function () {
  return tab === 'weekly' ? weeklyLog() : pageBeforeWeekly();
};

// Os scripts anteriores já desenharam o menu durante o carregamento; redesenha com a nova aba.
queueMicrotask(() => {
  if (typeof me === 'function' && me()) render();
});

async function loadWeeklyLog() {
  if (!isSysAdmin()) return;
  const request = ++weeklyRequest;
  weeklyLoading = true;
  weeklyError = '';
  if (tab === 'weekly') render();
  try {
    if (!window.sb) throw new Error('Conexão ao servidor indisponível.');
    // Garante que alterações recém-salvas já estejam no servidor antes de consultar.
    if (typeof saveChain !== 'undefined') await saveChain;
    const result = await window.sb.rpc('secap_weekly_log', {
      p_week: weeklyAnchor,
      p_weeks: WEEKLY_PAGE_SIZE,
    });
    if (request !== weeklyRequest) return;
    if (result.error) throw result.error;
    if (!Array.isArray(result.data?.weeks)) throw new Error('Resposta inválida do servidor.');
    weeklyData = result.data;
  } catch (error) {
    if (request !== weeklyRequest) return;
    weeklyData = null;
    weeklyError =
      'Não foi possível consultar o registro semanal. Verifique a conexão e se a migração 20261117150000_registro_semanal.sql foi aplicada. Detalhe: ' +
      String(error?.message || error);
  } finally {
    if (request === weeklyRequest) {
      weeklyLoading = false;
      if (tab === 'weekly' && isSysAdmin()) render();
    }
  }
}

function shiftWeeklyLog(direction) {
  if (weeklyLoading || !weeklyData) return;
  const base = new Date(`${weeklyData.newestWeek}T12:00:00`);
  base.setDate(base.getDate() + direction * 7 * WEEKLY_PAGE_SIZE);
  const next = base.toISOString().slice(0, 10);
  weeklyAnchor = next >= weeklyData.currentWeek ? null : next;
  loadWeeklyLog();
}

function weeklyGoCurrent() {
  weeklyAnchor = null;
  loadWeeklyLog();
}

const weeklyDate = (iso, year = true) => {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(iso || '')) return '—';
  const [y, m, d] = iso.split('-');
  return `${d}/${m}${year ? '/' + y : ''}`;
};

const weeklyTime = (at) => {
  const date = new Date(at);
  return Number.isNaN(date.getTime())
    ? '—'
    : date.toLocaleString('pt-BR', {
        weekday: 'short',
        day: '2-digit',
        month: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
      });
};

const weeklyRole = (role) =>
  role === 'administrador'
    ? 'Administrador'
    : role === 'usuario'
      ? 'Usuário'
      : 'Sem conta vinculada';

function weeklyValue(value) {
  const text =
    value === undefined || value === null || value === ''
      ? '—'
      : typeof value === 'object'
        ? JSON.stringify(value)
        : String(value);
  return text.length > 140
    ? `<span title="${esc(text)}">${esc(text.slice(0, 140))}…</span>`
    : esc(text);
}

function weeklyChange(change) {
  const fieldChange = change.field && change.field !== 'Obra';
  return `<li><time>${esc(weeklyTime(change.at))}</time><span><b>${esc(change.action || 'Alteração')}</b>${
    fieldChange
      ? ` · ${esc(change.field)}: <span class="weekly-before">${weeklyValue(change.before)}</span> → <span class="weekly-after">${weeklyValue(change.after)}</span>`
      : ''
  }</span></li>`;
}

function weeklyUser(user) {
  const records = Array.isArray(user.records) ? user.records : [];
  const other = Array.isArray(user.other) ? user.other : [];
  return `<details class="weekly-user">
    <summary>
      <span class="weekly-user-name"><b>${esc(user.name || 'Não informado')}</b><small>${esc(
        user.identified ? weeklyRole(user.role) : 'Registro sem conta identificada'
      )}</small></span>
      <span class="weekly-user-count">${user.changes} alteraç${user.changes === 1 ? 'ão' : 'ões'}${
        records.length ? ` · ${records.length} obra${records.length === 1 ? '' : 's'}` : ''
      }</span>
    </summary>
    ${
      records.length
        ? `<h4>Obras afetadas</h4>${records
            .map(
              (r) => `<div class="weekly-record">
          <p><b>${esc(r.record || r.recordId)}</b><small>${esc(r.project || '')}</small></p>
          <ul>${(r.changes || []).map(weeklyChange).join('')}</ul>
        </div>`
            )
            .join('')}`
        : ''
    }
    ${
      other.length
        ? `<h4>Configurações e outras ações</h4><ul class="weekly-other">${other
            .map(
              (o) =>
                `<li><time>${esc(weeklyTime(o.at))}</time><span><b>${esc(o.action || 'Ação')}</b> · ${esc(o.where || 'Portal')}${
                  o.before || o.after
                    ? `<br><span class="weekly-before">${weeklyValue(o.before)}</span> → <span class="weekly-after">${weeklyValue(o.after)}</span>`
                    : ''
                }</span></li>`
            )
            .join('')}</ul>`
        : ''
    }
  </details>`;
}

function weeklyWeek(week, data) {
  const isCurrent = week.start === data.currentWeek;
  const users = Array.isArray(week.users) ? week.users : [];
  const inactive = Array.isArray(week.inactive) ? week.inactive : [];
  const period = `${weeklyDate(week.start, false)} a ${weeklyDate(week.end)}`;
  return `<section class="panel weekly-week ${week.total ? '' : 'weekly-empty'}">
    <div class="panelhead">
      <div>
        <h2>Semana de ${esc(period)}</h2>
        <p class="subtitle">${
          week.total
            ? `${week.total} alteraç${week.total === 1 ? 'ão' : 'ões'} · ${week.records} obra${week.records === 1 ? '' : 's'} afetada${week.records === 1 ? '' : 's'} · ${users.length} pessoa${users.length === 1 ? '' : 's'} alter${users.length === 1 ? 'ou' : 'aram'}`
            : 'Sem alterações'
        }</p>
      </div>
      ${isCurrent ? '<span class="badge orange">Semana atual</span>' : ''}
    </div>
    <div class="panelbody">
      ${
        week.total
          ? users.map(weeklyUser).join('')
          : `<p class="weekly-none">${icon('check')}<span>Nada foi alterado no sistema entre ${esc(weeklyDate(week.start))} e ${esc(
              weeklyDate(week.end)
            )}${isCurrent ? ' até o momento' : ''}.</span></p>`
      }
      ${
        inactive.length
          ? `<div class="weekly-inactive"><span>${
              week.total ? 'Não fizeram alterações nesta semana:' : 'Nenhum usuário fez alterações:'
            }</span>${inactive
              .map(
                (u) =>
                  `<span class="weekly-chip">${esc(u.name)} <small>${esc(weeklyRole(u.role))}</small></span>`
              )
              .join('')}</div>`
          : ''
      }
    </div>
  </section>`;
}

function weeklyLog() {
  if (!isSysAdmin())
    return empty(
      'Acesso restrito',
      'O registro semanal está disponível apenas para administradores.'
    );
  if (!weeklyData && !weeklyLoading && !weeklyError) queueMicrotask(loadWeeklyLog);
  const data = weeklyData;
  const atCurrent = !data || data.newestWeek >= data.currentWeek;
  const nav = `<div class="weekly-nav">
      <button class="btn" ${weeklyLoading || !data?.hasOlder ? 'disabled' : ''} onclick="shiftWeeklyLog(-1)">← Semanas anteriores</button>
      <span>${data ? `${esc(weeklyDate(data.oldestWeek))} – ${esc(weeklyDate(data.weeks?.[0]?.end))}` : ''}</span>
      <button class="btn" ${weeklyLoading || atCurrent ? 'disabled' : ''} onclick="shiftWeeklyLog(1)">Semanas seguintes →</button>
    </div>`;
  return (
    head(
      'AUDITORIA DO SISTEMA',
      'Registro semanal',
      'O que foi alterado em cada semana, por quem, e quem não fez alterações. Os registros são gerados pelo servidor e não podem ser editados.',
      (atCurrent ? '' : btn('Semana atual', 'weeklyGoCurrent()', 'calendar')) +
        btn('Baixar relatório', "openReportExport('weekly')", 'download') +
        btn('Atualizar', 'loadWeeklyLog()', 'history')
    ) +
    (weeklyError ? `<div class="banner" role="alert">${esc(weeklyError)}</div>` : '') +
    (weeklyLoading ? '<p role="status">Consultando registros…</p>' : '') +
    (data
      ? nav +
        data.weeks.map((w) => weeklyWeek(w, data)).join('') +
        (data.hasOlder
          ? ''
          : `<p class="metric-note">Não há registros anteriores a ${esc(weeklyDate(data.firstEventWeek || data.oldestWeek))}.</p>`) +
        nav
      : '')
  );
}
