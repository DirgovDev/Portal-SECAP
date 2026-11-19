/* Consulta administrativa, sem alterar a configuração de permissões. */
let projectReviewId = '';
let projectReviewSearch = '';
let projectReviewLoading = false;
let projectReviewError = '';
let projectReviewToken = 0;
async function loadProjectVerification(pid = projectReviewId) {
  if (!isSysAdmin()) return;
  projectReviewId = pid || db.projects[0]?.id || '';
  const selected = projectReviewId,
    token = ++projectReviewToken;
  projectReviewLoading = true;
  projectReviewError = '';
  render();
  try {
    await loadWorkPermissionContext();
    if (workPermissionError) throw new Error(workPermissionError);
    const rows = [];
    if (selected)
      for (let offset = 0; ; offset += 500) {
        const response = await window.sb.rpc('secap_admin_permission_works', {
          p_project: selected,
          p_offset: offset,
        });
        if (response.error) throw response.error;
        if (token !== projectReviewToken) return;
        rows.push(...response.data.rows);
        if (rows.length >= response.data.total) break;
        if (!response.data.rows.length)
          throw new Error('Atualize a consulta: a lista de obras mudou.');
      }
    if (token === projectReviewToken) workPermissionPages.set(selected, rows);
  } catch (error) {
    if (token === projectReviewToken) projectReviewError = error.message;
  } finally {
    if (token === projectReviewToken) {
      projectReviewLoading = false;
      render();
    }
  }
}
function projectVerificationEntries(p, rows) {
  return (workPermissionContext?.users || []).map((u) => {
    const admin = u.role === 'administrador';
    const access = admin || u.projectScope === 'all' || u.projectIds?.includes(p.id);
    const ids =
      workPermissionContext?.effectiveWorks?.[u.id]?.[p.id] ??
      workPermissionContext?.works?.[u.id]?.[p.id];
    const explicit = Array.isArray(ids);
    const assigned = access ? (admin ? rows : rows.filter((r) => ids?.includes(r.id))) : [];
    const fields =
      access && (admin || u.obrasAccess === 'editar')
        ? admin
          ? p.fields
          : p.fields.filter((f) =>
              (workPermissionContext?.fields?.[u.email.toLowerCase()]?.[p.id] || []).includes(f.id)
            )
        : [];
    const editable = fields.length ? (admin ? rows : assigned) : [];
    return { u, admin, access, explicit, assigned, fields, editable };
  });
}
function adminProjectVerification() {
  if (!isSysAdmin()) return empty('Acesso restrito', 'Somente administradores.');
  const p = db.projects.find((p) => p.id === projectReviewId);
  const rows = workPermissionPages.get(projectReviewId) || [];
  const entries = p ? projectVerificationEntries(p, rows) : [];
  const q = projectReviewSearch.toLocaleLowerCase('pt-BR');
  const filtered = entries.filter((e) =>
    [
      e.u.name,
      e.u.email,
      ...e.assigned.map((r) => r.nome + ' ' + r.codigo),
      ...e.fields.map((f) => f.name),
    ]
      .join(' ')
      .toLocaleLowerCase('pt-BR')
      .includes(q)
  );
  const users = entries.filter((e) => e.access).length;
  const covered = new Set(entries.flatMap((e) => e.assigned.map((r) => r.id))).size;
  return `<section class="pv-page"><div class="pv-heading"><div><span class="pv-eyebrow">CONTROLE DE ACESSO</span><h2>Verificação do projeto</h2><p>Consulte as pessoas, as obras selecionadas e os campos liberados em um só lugar.</p></div><button class="btn" onclick="loadProjectVerification()">${icon('refresh')} Atualizar consulta</button></div>
  <div class="pv-controls"><div class="field"><label for="pvProject">Projeto / Pasta de Obras</label><select id="pvProject" onchange="projectReviewSearch='';loadProjectVerification(this.value)"><option value="">Selecione um projeto</option>${db.projects.map((item) => `<option value="${esc(item.id)}" ${item.id === projectReviewId ? 'selected' : ''}>${esc(item.name)}</option>`).join('')}</select></div><div class="field"><label for="pvSearch">Buscar na verificação</label><input id="pvSearch" type="search" placeholder="Usuário, obra ou campo" value="${esc(projectReviewSearch)}" oninput="filterProjectVerification(this.value)"></div></div>
  ${
    projectReviewLoading
      ? '<div class="pv-empty" role="status">Carregando pessoas, obras e campos…</div>'
      : projectReviewError
        ? `<div class="pv-empty wp-error" role="alert">${esc(projectReviewError)}</div>`
        : !p
          ? '<div class="pv-empty">Selecione um projeto para consultar as permissões.</div>'
          : `
  <div class="pv-metrics"><div><span>Pessoas com acesso ao projeto</span><strong>${users}</strong></div><div><span>Obras no projeto</span><strong>${rows.length}</strong></div><div><span>Obras vinculadas no Acompanhamento</span><strong>${covered}</strong></div></div>
  <div class="pv-section-title"><h3>Mapa de permissões</h3><span>${esc(p.name)}</span></div><div class="pv-people" id="pvPeople">${entries.map((e) => projectVerificationCard(e, filtered.includes(e))).join('')}</div><p id="pvNoResults" class="pv-empty" ${filtered.length ? 'hidden' : ''}>Nenhum resultado para esta busca.</p>`
  }</section>`;
}
function projectVerificationCard(e, shown = true) {
  const { u, admin, access, explicit, assigned, fields, editable } = e;
  const search = [
    u.name,
    u.email,
    ...assigned.map((r) => r.nome + ' ' + r.codigo),
    ...fields.map((f) => f.name),
  ]
    .join(' ')
    .toLocaleLowerCase('pt-BR');
  return `<details class="pv-person" data-search="${esc(search)}" ${shown ? '' : 'hidden'}><summary><div class="pv-avatar">${esc(
    String(u.name || u.email)
      .slice(0, 1)
      .toUpperCase()
  )}</div><div class="pv-identity"><strong>${esc(u.name || 'Usuário')}</strong><small>${esc(u.email)}</small></div><span class="pv-badge ${admin ? 'pv-admin' : !access ? 'pv-denied' : ''}">${admin ? 'Administrador · acesso integral' : access ? 'Acesso ao projeto' : 'Sem acesso ao projeto'}</span><div class="pv-counts"><span><b>${assigned.length}</b> obras no Acompanhamento</span><span><b>${fields.length}</b> campos editáveis</span></div><span class="pv-chevron" aria-hidden="true">⌄</span></summary><div class="pv-person-body"><section><h4>Obras no Acompanhamento</h4><div class="pv-work-names">${assigned.map((r) => `<div><b>${esc(r.nome || 'Obra sem nome')}</b><small>ID: ${esc(r.codigo || r.id)}</small></div>`).join('') || '<p>Nenhuma obra selecionada para esta pessoa.</p>'}</div></section><section><h4>Campos editáveis</h4><div class="pv-field-chips">${fields.map((f) => `<span>${esc(f.name)}</span>`).join('') || '<p>Nenhum campo liberado para edição.</p>'}</div><p class="pv-note">${!access ? 'Esta conta não tem acesso a este projeto.' : admin ? 'O administrador pode consultar e editar todas as obras e campos.' : editable.length ? `Edição permitida nos campos acima em ${editable.length} obra(s) selecionada(s).` : 'Consulta sem edição de campos liberada.'}</p></section></div></details>`;
}
function filterProjectVerification(value) {
  projectReviewSearch = value;
  const q = value.toLocaleLowerCase('pt-BR');
  let count = 0;
  document.querySelectorAll('.pv-person').forEach((el) => {
    el.hidden = !el.dataset.search.includes(q);
    if (!el.hidden) count++;
  });
  const empty = document.getElementById('pvNoResults');
  if (empty) empty.hidden = count > 0;
}
const verificationSetSectionBefore = setAdminSection;
setAdminSection = function (section = 'access') {
  verificationSetSectionBefore.apply(this, arguments);
  if (section === 'project-check') loadProjectVerification();
};
// Acompanhamento: somente vínculos explícitos do próprio usuário.
let myWorkSelectionReady = false,
  myWorkSelectionBusy = false,
  myWorkSelectionAt = 0,
  myWorkSelectionError = '';
async function refreshMyWorkSelection() {
  if (isSysAdmin() || myWorkSelectionBusy) return;
  myWorkSelectionBusy = true;
  myWorkSelectionError = '';
  try {
    const response = await window.sb.rpc('secap_my_work_selection');
    if (response.error) throw response.error;
    db.projectWorkAccess = response.data || {};
    myWorkSelectionReady = true;
    myWorkSelectionAt = Date.now();
  } catch (error) {
    myWorkSelectionReady = false;
    myWorkSelectionError =
      'Não foi possível consultar suas obras. Aplique supabase/security/project_permission_review.sql. ' +
      error.message;
  } finally {
    myWorkSelectionBusy = false;
    render();
  }
}
function canSeeAssignedWork(pid, rid) {
  if (isSysAdmin()) return true;
  if (!myWorkSelectionReady) return false;
  return Object.values(db.projectWorkAccess || {}).some(
    (map) => Array.isArray(map[pid]) && map[pid].includes(rid)
  );
}
const verificationKanbanBefore = kanban;
kanban = function () {
  if (isSysAdmin()) return verificationKanbanBefore.apply(this, arguments);
  if (myWorkSelectionError)
    return `<section class="panel"><div class="panelbody"><p role="alert">${esc(myWorkSelectionError)}</p><button class="btn" onclick="refreshMyWorkSelection()">Tentar novamente</button></div></section>`;
  if (!myWorkSelectionReady || Date.now() - myWorkSelectionAt > 15000) {
    if (!myWorkSelectionBusy) refreshMyWorkSelection();
    return '<section class="panel"><div class="panelbody" role="status">Consultando as obras selecionadas para você…</div></section>';
  }
  return verificationKanbanBefore.apply(this, arguments);
};
if (!isSysAdmin()) refreshMyWorkSelection();
