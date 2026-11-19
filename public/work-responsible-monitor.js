/* O vínculo de responsável usa a mesma seleção de obras das permissões. */
let kanbanResponsibleChoice = '';
function registeredWorkResponsibles(pid, rid) {
  return (workPermissionContext?.users || []).filter(
    (user) =>
      Array.isArray(workPermissionContext?.works?.[user.id]?.[pid]) &&
      workPermissionContext.works[user.id][pid].includes(rid)
  );
}
function kanbanResponsibleFilter() {
  if (!isSysAdmin()) return '';
  const users = workPermissionContext?.users || [];
  const registeredNames = new Set(
    users.map((user) => String(user.name || user.email).toLocaleLowerCase('pt-BR'))
  );
  const legacyNames = [
    ...new Set(visible().flatMap((p) => (p.records || []).flatMap((r) => workCardNames(r, p)))),
  ]
    .filter((name) => !registeredNames.has(name.toLocaleLowerCase('pt-BR')))
    .sort((a, b) => a.localeCompare(b, 'pt-BR'));
  return `<div class="kanban-responsible-filter"><label for="kanbanResponsible">Responsáveis</label><select id="kanbanResponsible" aria-label="Filtrar obras por responsável" onchange="setKanbanResponsible(this.value)"><option value="">Todos os responsáveis</option><option value="unassigned" ${kanbanResponsibleChoice === 'unassigned' ? 'selected' : ''}>Sem responsável</option>${users.map((user) => `<option value="${esc(user.id)}" ${kanbanResponsibleChoice === user.id ? 'selected' : ''}>${esc(user.name || user.email)}</option>`).join('')}${legacyNames.map((name) => `<option value="${esc('name:' + name)}" ${kanbanResponsibleChoice === 'name:' + name ? 'selected' : ''}>${esc(name)}</option>`).join('')}</select></div>`;
}
function setKanbanResponsible(value) {
  if (!isSysAdmin()) return;
  kanbanResponsibleChoice = value;
  render();
}
function matchesKanbanResponsible(p, r) {
  if (!isSysAdmin() || !kanbanResponsibleChoice) return true;
  const names = workCardNames(r, p);
  if (kanbanResponsibleChoice === 'unassigned') return !names.length;
  if (kanbanResponsibleChoice.startsWith('name:'))
    return names.includes(kanbanResponsibleChoice.slice(5));
  return registeredWorkResponsibles(p.id, r.id).some((user) => user.id === kanbanResponsibleChoice);
}
async function refreshWorkResponsibleLabels(pid) {
  const result = await window.sb.rpc('secap_work_responsible_labels', { p_project: pid });
  if (result.error)
    throw new Error(
      'Permissões salvas, mas é necessário recarregar os responsáveis: ' + result.error.message
    );
  const p = db.projects.find((p) => p.id === pid);
  if (!p) return;
  const labels = new Map((result.data || []).map((row) => [row.id, row.responsavel || '']));
  const ownerKey = workOwnerKey(p);
  for (const record of p.records || [])
    if (labels.has(record.id)) {
      record.responsavel = labels.get(record.id);
      record[ownerKey] = record.responsavel;
    }
  render();
}
