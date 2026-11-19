/* ============================================================================
   SECAP · SINO DE NOTIFICAÇÕES DO ADMINISTRADOR
   Para administradores, o sino do cabeçalho reúne as notificações acumuladas
   (notificações semanais de obras sem edição), com contador de não lidas.
   Para os demais usuários o sino continua levando ao Calendário.
   Dados: public.secap_admin_notifications / secap_admin_notifications_seen
   (supabase/security/admin_notifications.sql).
   ============================================================================ */

let adminBell = { data: null, error: '', loading: false, open: false, at: 0 };

function adminBellStatus(s) {
  return s === 'enviado' ? 'E-mail enviado' : s === 'teste' ? 'Gerado em modo teste' : s === 'erro' ? 'Falha no envio' : s;
}

function adminBellDate(iso) {
  const [y, m, d] = String(iso || '').split('-');
  return d ? `${d}/${m}/${y}` : '';
}

async function loadAdminBell(force = false) {
  if (!isSysAdmin() || !window.sb || adminBell.loading) return;
  if (!force && adminBell.data && Date.now() - adminBell.at < 60000) return paintAdminBell();
  adminBell.loading = true;
  try {
    const res = await window.sb.rpc('secap_admin_notifications', { p_limit: 60 });
    if (res.error) throw res.error;
    adminBell.data = res.data;
    adminBell.error = '';
  } catch (error) {
    adminBell.error = /secap_admin_notifications/.test(error?.message || '')
      ? 'Aplique supabase/security/admin_notifications.sql no banco.'
      : String(error?.message || error);
  } finally {
    adminBell.loading = false;
    adminBell.at = Date.now();
    paintAdminBell();
  }
}

// Ajusta o botão do sino que o render() desenha no cabeçalho.
function paintAdminBell() {
  const button = document.querySelector('.headright button[aria-label="Ver próximos prazos"], #adminBellButton');
  if (!button || !isSysAdmin()) return;
  const unread = Number(adminBell.data?.unread || 0);
  button.id = 'adminBellButton';
  button.classList.add('admin-bell');
  button.setAttribute('onclick', 'toggleAdminBell(event)');
  button.setAttribute('aria-haspopup', 'dialog');
  button.setAttribute('aria-expanded', String(adminBell.open));
  button.setAttribute('aria-label', unread ? `Notificações: ${unread} não lida(s)` : 'Notificações');
  button.title = unread ? `${unread} notificação(ões) não lida(s)` : 'Notificações';
  let badge = button.querySelector('.admin-bell-badge');
  if (unread) {
    if (!badge) {
      badge = document.createElement('span');
      badge.className = 'admin-bell-badge';
      button.appendChild(badge);
    }
    badge.textContent = unread > 99 ? '99+' : String(unread);
  } else if (badge) badge.remove();
  if (adminBell.open) renderAdminBellPanel();
}

function toggleAdminBell(event) {
  event?.stopPropagation();
  adminBell.open = !adminBell.open;
  if (!adminBell.open) return closeAdminBell();
  renderAdminBellPanel();
  loadAdminBell(true).then(markAdminBellSeen);
}

async function markAdminBellSeen() {
  if (!adminBell.data?.unread) return;
  const res = await window.sb.rpc('secap_admin_notifications_seen');
  if (res.error) return;
  // Mantém o destaque "Nova" enquanto o painel estiver aberto; zera só o contador.
  adminBell.data.unread = 0;
  paintAdminBell();
}

function closeAdminBell() {
  adminBell.open = false;
  document.getElementById('adminBellPanel')?.remove();
  document.getElementById('adminBellButton')?.setAttribute('aria-expanded', 'false');
  if (adminBell.data?.items) adminBell.data.items.forEach((item) => (item.unread = false));
}

function renderAdminBellPanel() {
  const button = document.getElementById('adminBellButton');
  if (!button) return;
  let panel = document.getElementById('adminBellPanel');
  if (!panel) {
    panel = document.createElement('section');
    panel.id = 'adminBellPanel';
    panel.className = 'admin-bell-panel';
    panel.setAttribute('role', 'dialog');
    panel.setAttribute('aria-label', 'Notificações');
    panel.addEventListener('click', (ev) => ev.stopPropagation());
    document.body.appendChild(panel);
  }
  const rect = button.getBoundingClientRect();
  panel.style.top = `${Math.round(rect.bottom + 8)}px`;
  panel.style.right = `${Math.max(12, Math.round(window.innerWidth - rect.right))}px`;
  const d = adminBell.data;
  const items = d?.items || [];
  const body = adminBell.error
    ? `<p class="admin-bell-empty" role="alert">${esc(adminBell.error)}</p>`
    : !d
      ? '<p class="admin-bell-empty" role="status">Carregando…</p>'
      : items.length
        ? `<ul class="admin-bell-list">${items
            .map(
              (n, i) => `<li><button type="button" class="admin-bell-item ${n.unread ? 'is-unread' : ''}" onclick="openAdminBellItem(${i})">
                <span class="admin-bell-kind is-${esc(n.status)}" aria-hidden="true">${icon('bell')}</span>
                <span class="admin-bell-text"><strong>${esc(n.name || n.email)} · ${n.total} obra(s) sem edição</strong>
                <small>Semana ${esc(adminBellDate(n.weekStart))} a ${esc(adminBellDate(n.weekEnd))} · ${esc(adminBellStatus(n.status))}</small>
                <small>${esc(new Date(n.at).toLocaleString('pt-BR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' }))}${n.unread ? ' · <b class="admin-bell-new">Nova</b>' : ''}</small></span>
              </button></li>`
            )
            .join('')}</ul>`
        : '<p class="admin-bell-empty">Nenhuma notificação por enquanto.</p>';
  panel.innerHTML = `<div class="admin-bell-head"><div><strong>Notificações</strong><small>${d ? `${d.total} no total` : ''}</small></div>
      <button type="button" class="iconbtn" aria-label="Fechar notificações" onclick="closeAdminBell()">${icon('close')}</button></div>
    ${body}
    <div class="admin-bell-foot"><button type="button" class="textbtn" onclick="closeAdminBell();go('weekly')">Abrir Registro semanal</button>
      <button type="button" class="textbtn" onclick="closeAdminBell();go('calendar')">Ver próximos prazos</button></div>`;
}

function openAdminBellItem(index) {
  const n = adminBell.data?.items?.[index];
  if (!n) return;
  closeAdminBell();
  const obras = Array.isArray(n.obras) ? n.obras : [];
  modal(
    'Notificação semanal',
    `<p><strong>${esc(n.name || '')}</strong> &lt;${esc(n.email)}&gt;<br>
      Semana de <strong>${esc(adminBellDate(n.weekStart))} a ${esc(adminBellDate(n.weekEnd))}</strong> · ${esc(adminBellStatus(n.status))}
      · ${esc(new Date(n.at).toLocaleString('pt-BR'))}${n.origin ? ` · ${esc(n.origin)}` : ''}</p>
     ${n.error ? `<div class="banner" role="alert">Erro: ${esc(n.error)}</div>` : ''}
     <p>${obras.length} obra(s) sem edição na semana:</p>
     <ul class="admin-bell-obras">${obras
       .map(
         (o) =>
           `<li>${esc(o.nome || 'Obra sem nome')}${o.codigo ? ` <small>ID ${esc(o.codigo)}</small>` : ''}${o.projectName ? `<br><small>${esc(o.projectName)}</small>` : ''}</li>`
       )
       .join('')}</ul>`,
    btn('Fechar', 'closeModal()', 'close') + btn('Abrir Registro semanal', "closeModal();go('weekly')", 'calendar', 'primary')
  );
}

// Fecha o painel ao clicar fora ou apertar Esc.
document.addEventListener('click', () => adminBell.open && closeAdminBell());
document.addEventListener('keydown', (ev) => ev.key === 'Escape' && adminBell.open && closeAdminBell());

// Reaplica o sino a cada redesenho da tela e consulta o contador periodicamente.
const renderBeforeAdminBell = render;
render = function () {
  const result = renderBeforeAdminBell.apply(this, arguments);
  if (typeof me === 'function' && me() && isSysAdmin()) {
    paintAdminBell();
    loadAdminBell();
  } else if (adminBell.open) closeAdminBell();
  return result;
};
setInterval(() => {
  if (typeof me === 'function' && me() && isSysAdmin()) loadAdminBell(true);
}, 120000);
queueMicrotask(() => {
  if (typeof me === 'function' && me() && isSysAdmin()) loadAdminBell(true);
});
