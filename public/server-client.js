let saveChain = Promise.resolve(),
  saveFailed = false,
  pendingSaves = 0;
function queueSave(state) {
  pendingSaves++;
  const snapshot = JSON.stringify({ state });
  saveChain = saveChain.then(async () => {
    try {
      const r = await fetch('/api/state', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: snapshot,
      });
      if (!r.ok) throw new Error((await r.json()).error);
      saveFailed = false;
      document.title = document.title.replace(' • Não salvo', '');
      return true;
    } catch (e) {
      saveFailed = true;
      document.title += ' • Não salvo';
      notify('Não foi possível salvar: ' + e.message);
      return false;
    } finally {
      pendingSaves--;
    }
  });
  return saveChain;
}
async function authenticate(form) {
  const msg = document.getElementById('authMessage');
  msg.textContent = 'Aguarde…';
  const loading = window.SECAPLoading;
  if (loading) loading.show('Verificando suas credenciais…');
  try {
    const r = await fetch(window.SECAP_SETUP ? '/api/setup' : '/api/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(Object.fromEntries(new FormData(form))),
    });
    const d = await r.json();
    if (!r.ok) throw new Error(d.error);
    // Mantém a tela de carregamento durante o recarregamento até o sistema abrir.
    if (loading) loading.show('Acesso confirmado. Carregando o sistema…', true);
    location.reload();
  } catch (e) {
    if (loading) loading.hide();
    msg.textContent = e.message;
  }
}
window.addEventListener('beforeunload', (e) => {
  if (saveFailed || pendingSaves) {
    e.preventDefault();
    e.returnValue = 'Existem alterações sem salvar.';
  }
});

async function submitRegistration(form) {
  const msg = document.getElementById('registerMessage');
  if (!msg) return;
  msg.textContent = 'Enviando solicitação…';
  try {
    const r = await fetch('/api/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(Object.fromEntries(new FormData(form))),
    });
    const d = await r.json();
    if (!r.ok) throw new Error(d.error || 'Não foi possível enviar a solicitação.');
    form.innerHTML = `<div class="registration-success"><h2>Espere o Administrador aceitar</h2><p>Seu cadastro foi recebido. O administrador irá avaliar as informações e liberar o seu acesso ao SECAP. Você só conseguirá entrar depois dessa aceitação.</p></div><button class="btn primary" type="button" onclick="showLogin()">Voltar para entrar</button>`;
  } catch (e) {
    msg.textContent = e.message;
  }
}
