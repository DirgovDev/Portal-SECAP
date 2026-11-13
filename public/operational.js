// Operational edition: single administrator, server persistence and backups.
adminSettings = function () {
  const s = db.portalSettings;
  return `<section class="panel"><div class="panelhead"><h2>Identificação do portal</h2></div><form id="portalSettingsForm" onsubmit="event.preventDefault();savePortalSettings()"><div class="panelbody"><div class="field"><label>Nome do portal</label><input required name="title" value="${esc(s.title)}"></div><div class="field"><label>Órgão responsável</label><input required name="department" value="${esc(s.department)}"></div><button class="btn primary">Salvar preferências</button></div></form></section><section class="panel"><div class="panelhead"><h2>Dados e continuidade</h2></div><div class="panelbody"><p>Projetos, obras, termos, anotações e configurações são armazenados no Supabase.</p><div class="actions"><button class="btn primary" onclick="downloadBackup()">Exportar backup completo</button><label class="btn">Restaurar backup<input hidden type="file" accept=".json,application/json" onchange="restoreBackup(this)"></label></div><p class="subtitle">A restauração substitui os dados atuais. Exporte um backup antes de continuar.</p></div></section>`;
};
async function downloadBackup() {
  await saveChain;
  if (saveFailed) return notify('Corrija o salvamento antes de exportar.');
  const r = await fetch('/api/backup');
  if (!r.ok) return notify('Não foi possível exportar. Entre novamente.');
  const blob = await r.blob(),
    a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = 'secap-backup-' + today() + '.json';
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 5000);
}
async function restoreBackup(input) {
  try {
    const b = JSON.parse(await input.files[0].text());
    if (
      b.format !== 'secap-server-v1' ||
      !b.state ||
      !['projects', 'notes', 'logs', 'terms', 'users'].every((k) => Array.isArray(b.state[k]))
    )
      throw new Error('Arquivo incompatível');
    if (!confirm('Substituir todos os dados atuais pelo backup selecionado?')) return;
    await saveChain;
    const r = await fetch('/api/restore', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        state: b.state,
        ...(Array.isArray(b.private_calendar) ? { private_calendar: b.private_calendar } : {}),
        ...(b.modernization && typeof b.modernization === 'object' ? { modernization: b.modernization } : {}),
      }),
    });
    if (!r.ok) throw new Error((await r.json()).error);
    location.reload();
  } catch (e) {
    notify('Não foi possível restaurar: ' + e.message);
  } finally {
    input.value = '';
  }
}
requestAccess = function () {
  notify('Esta edição é exclusiva do administrador.');
};
submitRequest = function () {};
editUser = function () {};
saveUser = function () {};
logout = async function () {
  await saveChain;
  if (saveFailed) return notify('Exporte ou corrija as alterações antes de sair.');
  await fetch('/api/logout', { method: 'POST' });
  location.reload();
};
