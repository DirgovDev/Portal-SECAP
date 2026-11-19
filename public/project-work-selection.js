/* Permissões de edição: usuário cadastrado -> projeto -> obras -> campos. */
let workPermissionContext = null;
let workPermissionDraft = null;
let workPermissionLoading = false;
let workPermissionError = '';
let workPermissionGeneration = 0;
const workPermissionPages = new Map();
async function loadWorkPermissionContext() {
  if (!isSysAdmin()) return;
  try {
    const response = await window.sb.rpc('secap_admin_permission_context');
    if (response.error) throw response.error;
    workPermissionContext = response.data;
    db.projectWorkAccess = response.data.works || {};
    db.fieldPermissions = response.data.fields || {};
    workPermissionError = '';
  } catch (error) {
    workPermissionError =
      'Não foi possível consultar as permissões. Aplique supabase/security/responsible_acompanhamento_access.sql. ' +
      error.message;
  }
  render();
}
async function chooseWorkPermission() {
  const user = document.getElementById('wpUser').value;
  const project = document.getElementById('wpProject').value;
  const account = workPermissionContext?.users.find((u) => u.id === user);
  const works = workPermissionContext?.works?.[user]?.[project];
  workPermissionDraft = {
    user,
    project,
    works: new Set(Array.isArray(works) ? works : []),
    names: new Map(
      (workPermissionContext?.responsibleLinks?.[user]?.[project] || []).map((n) => [
        acompanhamentoKey(n),
        n,
      ])
    ),
    fields: new Set(
      workPermissionContext?.fields?.[account?.email?.toLowerCase()]?.[project] || []
    ),
  };
  const generation = ++workPermissionGeneration;
  workPermissionError = '';
  if (!project || !user) {
    workPermissionLoading = false;
    render();
    return;
  }
  workPermissionLoading = true;
  workPermissionPages.delete(project);
  render();
  try {
    const rows = [];
    let total;
    for (let offset = 0; ; offset += 500) {
      const response = await window.sb.rpc('secap_admin_permission_works', {
        p_project: project,
        p_offset: offset,
      });
      if (generation !== workPermissionGeneration) return;
      if (response.error) throw response.error;
      total = response.data.total;
      rows.push(...response.data.rows);
      if (rows.length >= total) break;
      if (!response.data.rows.length) throw new Error('A lista mudou. Atualize e tente novamente.');
    }
    if (new Set(rows.map((row) => row.id)).size !== rows.length)
      throw new Error('A lista mudou. Atualize e tente novamente.');
    workPermissionPages.set(project, rows);
  } catch (error) {
    if (generation === workPermissionGeneration) workPermissionError = error.message;
  } finally {
    if (generation === workPermissionGeneration) {
      workPermissionLoading = false;
      render();
    }
  }
}
adminFieldPermissions = function () {
  if (!isSysAdmin()) return empty('Acesso restrito', 'Somente administradores.');
  const d = workPermissionDraft || {
    user: '',
    project: '',
    works: new Set(),
    names: new Map(),
    fields: new Set(),
  };
  const p = db.projects.find((p) => p.id === d.project);
  const rows = workPermissionPages.get(d.project) || [];
  const ready =
    !!workPermissionContext &&
    !workPermissionLoading &&
    !workPermissionError &&
    workPermissionPages.has(d.project);
  return `<section class="panel"><div class="panelhead"><div><h2>Permissões do projeto</h2><p>Escolha o usuário, vincule o Responsável Acompanhamento e os campos que ele pode editar.</p></div><button class="btn" onclick="loadWorkPermissionContext()">Atualizar usuários e permissões</button></div><div class="panelbody">
  ${workPermissionError ? `<p class="wp-error" role="alert">${esc(workPermissionError)}</p>` : ''}
  ${!workPermissionContext ? '<p>Carregando usuários cadastrados…</p>' : ''}
  <div class="twocol"><div class="field"><label for="wpUser">1. Usuário</label><select id="wpUser" onchange="chooseWorkPermission()"><option value="">Selecione um usuário</option>${(workPermissionContext?.users || []).map((u) => `<option value="${esc(u.id)}" ${u.id === d.user ? 'selected' : ''}>${esc(u.name || u.email)}${u.name ? ' (' + esc(u.email) + ')' : ''}</option>`).join('')}</select></div><div class="field"><label for="wpProject">2. Projeto / Pasta de Obras</label><select id="wpProject" onchange="chooseWorkPermission()"><option value="">Selecione um projeto</option>${db.projects.map((p) => `<option value="${esc(p.id)}" ${p.id === d.project ? 'selected' : ''}>${esc(p.name)}</option>`).join('')}</select></div></div>
  ${
    p && d.user
      ? `<form id="wpForm" onsubmit="event.preventDefault();saveWorkPermissionSelection()">${acompanhamentoPicker(rows, d)}<h3>4. Obras deste usuário</h3><p>${workPermissionLoading ? 'Carregando todas as obras…' : `${rows.length} obras no projeto. As automáticas vêm do Responsável Acompanhamento; marque aqui apenas exceções individuais.`}</p><div class="actions"><button class="btn" type="button" onclick="chooseWorkPermission()">Atualizar lista de obras</button><button class="btn" type="button" onclick="toggleWorkPermissionRows(true)">Marcar obras visíveis</button><button class="btn" type="button" onclick="toggleWorkPermissionRows(false)">Desmarcar obras visíveis</button></div><div class="field"><input type="search" aria-label="Buscar obra por nome ou ID" placeholder="Buscar obra por nome ou ID" oninput="filterWorkPermissionRows(this.value)"></div><div class="wp-work-list">${rows.map((r) => `<label class="wp-work${acompanhamentoLinkedBy(r, d) ? ' wp-auto' : ''}" data-search="${esc([r.nome, r.codigo, r.id, r.acompanhamento].join(' ').toLocaleLowerCase('pt-BR'))}"><input type="checkbox" value="${esc(r.id)}" ${acompanhamentoLinkedBy(r, d) || d.works.has(r.id) ? 'checked' : ''} ${acompanhamentoLinkedBy(r, d) ? 'disabled' : ''} onchange="this.checked?workPermissionDraft.works.add(this.value):workPermissionDraft.works.delete(this.value);updateWorkPermissionCount()"><span>${esc(r.nome || 'Obra sem nome')}<small>ID: ${esc(r.codigo || r.id)} · Responsável Acompanhamento: ${esc(r.acompanhamento || 'não informado')}</small><i class="wp-auto-tag">${acompanhamentoLinkedBy(r, d) ? 'Automática · ' + esc(acompanhamentoLinkedBy(r, d)) : ''}</i></span></label>`).join('') || (!workPermissionLoading ? '<p>Nenhuma obra cadastrada neste projeto.</p>' : '')}</div><p id="wpCount">${workPermissionSummary(d)}</p>
  <h3>5. Campos que o usuário pode editar nas obras selecionadas</h3><p>Os campos não selecionados permanecem somente para leitura.</p><div class="actions"><button class="btn" type="button" onclick="toggleWorkPermissionFields(true)">Marcar todos os campos</button><button class="btn" type="button" onclick="toggleWorkPermissionFields(false)">Desmarcar todos os campos</button></div><div class="template-grid">${p.fields.map((f) => `<label class="template-option"><input type="checkbox" name="wpField" value="${esc(f.id)}" ${d.fields.has(f.id) ? 'checked' : ''} onchange="this.checked?workPermissionDraft.fields.add(this.value):workPermissionDraft.fields.delete(this.value)"><span>${esc(f.name)}</span></label>`).join('')}</div><p id="wpSaveError" role="alert"></p><button type="submit" class="btn primary" ${ready ? '' : 'disabled'}>Salvar permissões do projeto</button></form>`
      : ''
  }
  </div></section>`;
};
/* Responsável Acompanhamento: campo principal. Nomes vinculados liberam automaticamente
   todas as obras cujo campo contenha o nome (inclusive obras futuras ou alteradas). */
const WP_NO_RESPONSIBLE = '\u0000sem-responsavel';
function acompanhamentoNames(value) {
  const names = String(value || '')
    .split(/\s*[\/;,]\s*|\s+e\s+/i)
    .map((n) => n.trim())
    .filter(Boolean);
  return names.length ? names : [WP_NO_RESPONSIBLE];
}
function acompanhamentoKey(name) {
  return String(name)
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/\s+/g, ' ')
    .trim()
    .toLocaleLowerCase('pt-BR');
}
function acompanhamentoGroups(rows) {
  const groups = new Map();
  rows.forEach((r) =>
    acompanhamentoNames(r.acompanhamento).forEach((name) => {
      const key = name === WP_NO_RESPONSIBLE ? name : acompanhamentoKey(name);
      if (!groups.has(key)) groups.set(key, { key, name, ids: [] });
      groups.get(key).ids.push(r.id);
    })
  );
  return [...groups.values()].sort((a, b) =>
    a.key === WP_NO_RESPONSIBLE
      ? 1
      : b.key === WP_NO_RESPONSIBLE
        ? -1
        : a.name.localeCompare(b.name, 'pt-BR')
  );
}
function acompanhamentoLinkedBy(r, d) {
  return acompanhamentoNames(r.acompanhamento).find(
    (n) => n !== WP_NO_RESPONSIBLE && d.names.has(acompanhamentoKey(n))
  );
}
function acompanhamentoCovered(d) {
  const covered = new Set();
  (workPermissionPages.get(d.project) || []).forEach((r) => {
    if (acompanhamentoLinkedBy(r, d)) covered.add(r.id);
  });
  return covered;
}
function acompanhamentoChipState(group, d) {
  if (group.key !== WP_NO_RESPONSIBLE) return d.names.has(group.key) ? 'all' : 'none';
  const marked = group.ids.filter((id) => d.works.has(id)).length;
  return marked === 0 ? 'none' : marked === group.ids.length ? 'all' : 'some';
}
function acompanhamentoChip(key, label, count, state, suggested, title) {
  return `<button type="button" class="wp-acomp-chip" data-key="${esc(key)}" data-state="${state}" aria-pressed="${state === 'all'}" title="${esc(title)}" onclick="toggleAcompanhamentoGroup(this.dataset.key)"><span>${esc(label)}</span><b>${count}</b>${suggested ? '<em>sugerido</em>' : ''}</button>`;
}
function acompanhamentoPicker(rows, d) {
  if (!rows.length) return '';
  if (!rows.some((r) => r.acompanhamento))
    return '<p class="wp-acomp-note">Este projeto não possui o campo “Responsável Acompanhamento” preenchido. Selecione as obras na lista abaixo.</p>';
  const account = workPermissionContext?.users.find((u) => u.id === d.user);
  const userKey = acompanhamentoKey(String(account?.name || '').split(/\s+/)[0] || '');
  const groups = acompanhamentoGroups(rows);
  const chips = groups
    .map((g) => {
      const none = g.key === WP_NO_RESPONSIBLE;
      return acompanhamentoChip(
        g.key,
        none ? 'Sem responsável' : g.name,
        g.ids.length,
        acompanhamentoChipState(g, d),
        userKey && !none && g.key.split(' ')[0] === userKey,
        none
          ? 'Marca individualmente as obras sem responsável'
          : 'Vincula a conta a este nome: as obras com este Responsável Acompanhamento ficam liberadas automaticamente'
      );
    })
    .join('');
  // Nomes vinculados que hoje não aparecem em nenhuma obra continuam salvos e visíveis.
  const present = new Set(groups.map((g) => g.key));
  const orphan = [...d.names]
    .filter(([key]) => !present.has(key))
    .map(([key, name]) =>
      acompanhamentoChip(key, name, 0, 'all', false, 'Nome vinculado sem obras no momento')
    )
    .join('');
  return `<h3>3. Responsável Acompanhamento vinculado a esta conta</h3><p>Selecione o(s) nome(s) que correspondem a esta pessoa. Ela verá e poderá trabalhar automaticamente em todas as obras com esse Responsável Acompanhamento — inclusive obras novas ou que passem a ter esse nome.</p><div class="wp-acomp-chips">${chips}${orphan}</div>`;
}
function toggleAcompanhamentoGroup(key) {
  const d = workPermissionDraft;
  if (!d) return;
  const rows = workPermissionPages.get(d.project) || [];
  const group = acompanhamentoGroups(rows).find((g) => g.key === key);
  if (key === WP_NO_RESPONSIBLE) {
    if (!group) return;
    const select = acompanhamentoChipState(group, d) !== 'all';
    group.ids.forEach((id) => (select ? d.works.add(id) : d.works.delete(id)));
  } else if (d.names.has(key)) {
    d.names.delete(key);
  } else {
    d.names.set(key, group ? group.name : key);
  }
  syncWorkPermissionChecks();
}
function syncWorkPermissionChecks() {
  const d = workPermissionDraft;
  const rows = new Map((workPermissionPages.get(d.project) || []).map((r) => [r.id, r]));
  document.querySelectorAll('.wp-work').forEach((label) => {
    const input = label.querySelector('input');
    const r = rows.get(input.value);
    const by = r && acompanhamentoLinkedBy(r, d);
    input.checked = !!by || d.works.has(input.value);
    input.disabled = !!by;
    label.classList.toggle('wp-auto', !!by);
    const tag = label.querySelector('.wp-auto-tag');
    if (tag) tag.textContent = by ? 'Automática · ' + by : '';
  });
  updateWorkPermissionCount();
}
function workPermissionSummary(d) {
  const covered = acompanhamentoCovered(d);
  const individual = [...d.works].filter((id) => !covered.has(id)).length;
  return `${covered.size} obra(s) automática(s) pelo Responsável Acompanhamento · ${individual} individual(is).`;
}
function refreshAcompanhamentoChips() {
  const d = workPermissionDraft;
  if (!d) return;
  const groups = acompanhamentoGroups(workPermissionPages.get(d.project) || []);
  document.querySelectorAll('.wp-acomp-chip').forEach((el) => {
    const g = groups.find((x) => x.key === el.dataset.key) || { key: el.dataset.key, ids: [] };
    const state = acompanhamentoChipState(g, d);
    el.dataset.state = state;
    el.setAttribute('aria-pressed', String(state === 'all'));
  });
}
function filterWorkPermissionRows(q) {
  const query = String(q).toLocaleLowerCase('pt-BR');
  document
    .querySelectorAll('.wp-work')
    .forEach((el) => (el.hidden = !el.dataset.search.includes(query)));
}
function updateWorkPermissionCount() {
  const el = document.getElementById('wpCount');
  if (el) el.textContent = workPermissionSummary(workPermissionDraft);
  refreshAcompanhamentoChips();
}
function toggleWorkPermissionRows(checked) {
  document.querySelectorAll('.wp-work:not([hidden]) input:not(:disabled)').forEach((el) => {
    el.checked = checked;
    checked ? workPermissionDraft.works.add(el.value) : workPermissionDraft.works.delete(el.value);
  });
  updateWorkPermissionCount();
}
function toggleWorkPermissionFields(checked) {
  document.querySelectorAll('[name=wpField]').forEach((el) => {
    el.checked = checked;
    checked
      ? workPermissionDraft.fields.add(el.value)
      : workPermissionDraft.fields.delete(el.value);
  });
}
async function saveWorkPermissionSelection() {
  if (!isSysAdmin() || !workPermissionDraft || workPermissionLoading || workPermissionError) return;
  const form = document.getElementById('wpForm'),
    button = form.querySelector('[type=submit]');
  if (button.disabled) return;
  const d = workPermissionDraft;
  button.disabled = true;
  try {
    if (typeof saveChain !== 'undefined') await saveChain;
    // Obras cobertas pelo nome vinculado não são gravadas como exceção individual:
    // assim o acesso continua acompanhando o campo Responsável Acompanhamento.
    const covered = acompanhamentoCovered(d);
    const r = await window.sb.rpc('secap_admin_save_project_permissions', {
      p_user: d.user,
      p_project: d.project,
      p_works: [...d.works].filter((id) => !covered.has(id)),
      p_fields: [...d.fields],
      p_responsibles: [...d.names.values()],
    });
    if (r.error) throw r.error;
    await loadWorkPermissionContext();
    if (typeof refreshWorkResponsibleLabels === 'function')
      await refreshWorkResponsibleLabels(d.project);
    notify('Obras, responsáveis e campos permitidos salvos.');
  } catch (error) {
    const target = document.getElementById('wpSaveError');
    if (target) target.textContent = error.message;
    notify(error.message, 'error');
    button.disabled = false;
  }
}
function canEditSelectedWork(pid, rid) {
  if (isSysAdmin() || !rid) return true;
  const email = String(window.SECAP_EMAIL || me()?.email || '').toLowerCase();
  // O estado do membro só contém a própria seleção, identificada pelo ID da conta.
  const rules = Object.values(db.projectWorkAccess || {});
  return rules.some((map) => Array.isArray(map[pid]) && map[pid].includes(rid));
}
const workSelectionOpenBefore = openRecordForm;
openRecordForm = function (pid, rid = '') {
  if (!canEditSelectedWork(pid, rid))
    return notify('Esta obra não está liberada para edição na sua conta.', 'error');
  return workSelectionOpenBefore.apply(this, arguments);
};
const workSelectionMoveBefore = moveObra;
moveObra = function (pid, rid) {
  if (!canEditSelectedWork(pid, rid))
    return notify('Esta obra não está liberada para edição na sua conta.', 'error');
  return workSelectionMoveBefore.apply(this, arguments);
};
const workSelectionSaveBefore = saveRecord;
saveRecord = function (pid, rid = '') {
  if (!canEditSelectedWork(pid, rid))
    return notify('Esta obra não está liberada para edição na sua conta.', 'error');
  return workSelectionSaveBefore.apply(this, arguments);
};
if (isSysAdmin()) loadWorkPermissionContext();
