/* ============================================================================
   SECAP · NOTIFICAÇÃO SEMANAL POR E-MAIL (somente administradores)
   Painel no Registro semanal: mostra quem será notificado sobre obras sem edição na
   semana anterior e permite enviar na hora. O envio é feito pelo servidor do portal
   (weekly_notify.py), que também agenda o envio automático (segunda, 08:00) e grava
   cada notificação na Auditoria.
   ============================================================================ */

let weeklyNotify = { loading: false, data: null, error: '', result: null };

async function weeklyNotifyCall(path, body) {
  const session = await window.sb?.auth?.getSession?.();
  const token = session?.data?.session?.access_token;
  if (!token) throw new Error('Sessão expirada. Entre novamente.');
  const response = await fetch(path, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + token },
    body: JSON.stringify(body || {}),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(data.error || 'Falha na consulta (' + response.status + ').');
  return data;
}

async function loadWeeklyNotifyPreview() {
  if (!isSysAdmin()) return;
  weeklyNotify = { ...weeklyNotify, loading: true, error: '' };
  if (tab === 'weekly') render();
  try {
    weeklyNotify.data = await weeklyNotifyCall('/api/weekly-notify/preview', {});
  } catch (error) {
    weeklyNotify.error = String(error?.message || error);
  } finally {
    weeklyNotify.loading = false;
    if (tab === 'weekly') render();
  }
}

function confirmWeeklyNotify() {
  const d = weeklyNotify.data;
  if (!d) return;
  const pending = (d.accounts || []).filter((a) => !['enviado', 'teste'].includes(a.lastStatus));
  if (!pending.length)
    return notify('Todas as contas desta semana já foram notificadas.', 'error');
  modal(
    'Enviar notificação semanal?',
    `<p>Será enviado um e-mail para <strong>${pending.length} conta(s)</strong> com as obras vinculadas que não tiveram edição na semana de <strong>${esc(weeklyDate(d.weekStart))} a ${esc(weeklyDate(d.weekEnd))}</strong>.</p>
     <p>${esc(d.modo || '')}${/teste/.test(d.modo || '') ? ' — nenhum e-mail sai do computador; os arquivos ficam em data/weekly-notify-outbox.' : ''}</p>
     <p>Cada envio fica registrado na Auditoria.</p>`,
    btn('Cancelar', 'closeModal()', 'close') +
      `<button class="btn primary" type="button" onclick="runWeeklyNotify(this)">${icon('check')} Enviar agora</button>`
  );
}

async function runWeeklyNotify(button) {
  if (button) {
    button.disabled = true;
    button.textContent = 'Enviando…';
  }
  try {
    weeklyNotify.result = await weeklyNotifyCall('/api/weekly-notify/run', {
      week: weeklyNotify.data?.weekStart,
    });
    const r = weeklyNotify.result;
    notify(
      `Notificação semanal: ${r.enviados} enviada(s), ${r.teste} em modo teste, ${r.erros} com erro.`,
      r.erros ? 'error' : undefined
    );
    closeModal();
    await loadWeeklyNotifyPreview();
    if (typeof auditLoaded !== 'undefined') auditLoaded = false;
  } catch (error) {
    notify(String(error?.message || error), 'error');
    if (button) {
      button.disabled = false;
      button.textContent = 'Enviar agora';
    }
  }
}

function weeklyNotifyPanel() {
  const n = weeklyNotify;
  const d = n.data;
  const statusLabel = (s) =>
    s === 'enviado' ? 'Enviado' : s === 'teste' ? 'Gerado (teste)' : s === 'erro' ? 'Erro' : 'Pendente';
  const list = d
    ? (d.accounts || []).length
      ? `<table class="weekly-notify-table"><thead><tr><th>Conta</th><th>E-mail</th><th>Obras sem edição</th><th>Situação</th></tr></thead><tbody>${d.accounts
          .map(
            (a) =>
              `<tr><td>${esc(a.name)}</td><td>${esc(a.email)}</td><td><details><summary>${a.total} obra(s)</summary><ul>${(a.obras || [])
                .map((o) => `<li>${esc(o.nome || 'Obra sem nome')}${o.codigo ? ` <small>ID ${esc(o.codigo)}</small>` : ''}</li>`)
                .join('')}</ul></details></td><td><span class="weekly-notify-status is-${esc(a.lastStatus || 'pendente')}">${statusLabel(a.lastStatus)}</span></td></tr>`
          )
          .join('')}</tbody></table>`
      : '<p class="metric-note">Nenhuma conta vinculada tem obras sem edição nessa semana.</p>'
    : '';
  return `<section class="panel weekly-notify-panel"><div class="panelhead"><div><h2>Notificação semanal por e-mail</h2>
    <small>Toda segunda-feira, às 08:00, cada conta vinculada recebe a lista das suas obras que não tiveram edição na semana anterior. Os envios ficam registrados na Auditoria.</small></div>
    <div class="actions">${btn(n.loading ? 'Consultando…' : d ? 'Atualizar lista' : 'Ver quem será notificado', 'loadWeeklyNotifyPreview()', 'eye')}
    ${d ? `<button class="btn primary" type="button" onclick="confirmWeeklyNotify()">${icon('check')} Enviar agora</button>` : ''}</div></div>
    <div class="panelbody">
      ${n.error ? `<div class="banner" role="alert">${esc(n.error)}</div>` : ''}
      ${d ? `<p class="weekly-notify-week">Semana de <strong>${esc(weeklyDate(d.weekStart))} a ${esc(weeklyDate(d.weekEnd))}</strong> · ${esc(d.modo || '')}</p>${list}` : ''}
    </div></section>`;
}

const weeklyLogBeforeNotify = weeklyLog;
weeklyLog = function () {
  const html = weeklyLogBeforeNotify.apply(this, arguments);
  if (!isSysAdmin()) return html;
  // Painel logo após o cabeçalho da página (head() termina em "</div></div></div>").
  const start = html.indexOf('<div class="pagehead">');
  const end = start < 0 ? -1 : html.indexOf('</div></div></div>', start);
  if (end < 0) return weeklyNotifyPanel() + html;
  const cut = end + '</div></div></div>'.length;
  return html.slice(0, cut) + weeklyNotifyPanel() + html.slice(cut);
};
