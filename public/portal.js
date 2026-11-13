/* portal.js — acessibilidade complementar (não altera a lógica do sistema) */
(function () {
  'use strict';
  function enhance() {
    var main = document.querySelector('.main');
    if (main && !main.id) {
      main.id = 'conteudo-principal';
      main.setAttribute('tabindex', '-1');
    }
    var nav = document.querySelector('.sidebar');
    if (nav && !nav.getAttribute('aria-label'))
      nav.setAttribute('aria-label', 'Navegação principal');
    var active = document.querySelector('.nav.active');
    if (active) active.setAttribute('aria-current', 'page');
    document.querySelectorAll('.nav:not(.active)[aria-current]').forEach(function (n) {
      n.removeAttribute('aria-current');
    });
    var tgl = document.getElementById('menu-toggle');
    if (tgl) {
      tgl.hidden = !document.querySelector('.sidebar'); /* some na tela de login */
      var open = !document.body.classList.contains('menu-collapsed');
      tgl.setAttribute('aria-expanded', String(open));
      tgl.title = open ? 'Ocultar menu' : 'Mostrar menu';
    }
    var hb = document.querySelector('.mobilemenu');
    if (hb) {
      hb.setAttribute('aria-controls', 'sidebar');
      hb.setAttribute('aria-expanded', String(!document.body.classList.contains('menu-collapsed')));
      hb.setAttribute('title', 'Mostrar/ocultar menu');
    }
    document.querySelectorAll('.iconbtn:not([aria-label]):not([title])').forEach(function (b) {
      if (!b.textContent.trim()) b.setAttribute('aria-label', 'Botão de ação');
    });
  }
  if (!document.querySelector('.skip-link')) {
    var a = document.createElement('a');
    a.className = 'skip-link';
    a.href = '#conteudo-principal';
    a.textContent = 'Ir para o conteúdo';
    a.addEventListener('click', function () {
      var m = document.getElementById('conteudo-principal');
      if (m) m.focus();
    });
    document.body.insertBefore(a, document.body.firstChild);
  }
  /* Menu hambúrguer: recolhe/expande o menu lateral no desktop */
  var KEY = 'secap-menu-collapsed';
  try {
    if (localStorage.getItem(KEY) === '1') document.body.classList.add('menu-collapsed');
  } catch (e) {}
  document.addEventListener(
    'click',
    function (ev) {
      var btn = ev.target.closest && ev.target.closest('.mobilemenu');
      if (!btn || window.innerWidth <= 720) return; /* no celular vale o comportamento original */
      ev.preventDefault();
      ev.stopPropagation();
      var collapsed = document.body.classList.toggle('menu-collapsed');
      try {
        localStorage.setItem(KEY, collapsed ? '1' : '0');
      } catch (e) {}
      enhance();
    },
    true
  );
  /* Botão hambúrguer fixo ao lado da logo (fica fora do #app, então não é recriado) */
  var tg = document.createElement('button');
  tg.id = 'menu-toggle';
  tg.type = 'button';
  tg.setAttribute('aria-controls', 'sidebar');
  tg.setAttribute('aria-label', 'Mostrar ou ocultar o menu lateral');
  tg.innerHTML = '<span></span><span></span><span></span>';
  tg.addEventListener('click', function () {
    var c = document.body.classList.toggle('menu-collapsed');
    try {
      localStorage.setItem(KEY, c ? '1' : '0');
    } catch (e) {}
    enhance();
  });
  document.body.appendChild(tg);
  var t;
  new MutationObserver(function () {
    clearTimeout(t);
    t = setTimeout(enhance, 50);
  }).observe(document.getElementById('app') || document.body, { childList: true, subtree: true });
  enhance();
})();

/* ---- Botão "voltar ao topo" (canto inferior direito) ---- */
(function () {
  'use strict';
  var THRESHOLD = 320,
    scroller = null;
  var b = document.createElement('button');
  b.id = 'back-to-top';
  b.type = 'button';
  b.hidden = true;
  b.setAttribute('aria-label', 'Voltar ao topo');
  b.title = 'Voltar ao topo';
  b.innerHTML =
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 19V5 M5 12l7-7 7 7"/></svg>';
  document.body.appendChild(b);

  function offset() {
    return Math.max(
      window.scrollY || 0,
      scroller && document.body.contains(scroller) ? scroller.scrollTop : 0
    );
  }
  function update() {
    var show = offset() > THRESHOLD;
    b.hidden = false;
    b.classList.toggle('is-visible', show);
    b.tabIndex = show ? 0 : -1;
  }
  document.addEventListener(
    'scroll',
    function (ev) {
      var t = ev.target;
      if (
        t !== document &&
        t.scrollTop > THRESHOLD &&
        t.scrollHeight > t.clientHeight + 200 &&
        !t.closest('#search-suggest')
      )
        scroller = t;
      update();
    },
    true
  );
  b.addEventListener('click', function () {
    var smooth = !window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    var opt = { top: 0, behavior: smooth ? 'smooth' : 'auto' };
    if (scroller && document.body.contains(scroller) && scroller.scrollTop > (window.scrollY || 0))
      scroller.scrollTo(opt);
    else window.scrollTo(opt);
  });
  update();
})();
/* ---- Decisão de acesso ao sistema (aprovar / recusar) ---- */
window.handleAccountRequestAction = function (id, action) {
  const requestId = Number(id);
  if (!Number.isSafeInteger(requestId) || requestId < 1 || !['approve', 'reject'].includes(action)) {
    notify('Cadastro ou ação inválida. Atualize a lista e tente novamente.');
    return;
  }
  const item = (typeof accountRequestsCache !== 'undefined' ? accountRequestsCache : []).find(
    (r) => Number(r.id) === requestId
  );
  if (!item) {
    notify('Cadastro não encontrado. Atualize a lista e tente novamente.');
    return;
  }
  const approve = action === 'approve';
  modal(
    approve ? 'Aprovar acesso' : 'Recusar acesso',
    `<p style="margin:0 0 6px"><strong>${esc(item.name || 'Nome não informado')}</strong></p><p class="subtitle" style="margin:0 0 14px">${esc(item.email || '')}${item.job_title ? ' · ' + esc(item.job_title) : ''}</p><p style="margin:0">${approve ? 'Confirma a aprovação do acesso desta pessoa ao sistema?' : 'Confirma a recusa do acesso desta pessoa ao sistema?'} A decisão fica registrada e não pode ser alterada por aqui.</p>`,
    `<button class="btn" type="button" onclick="closeModal()">Cancelar</button><button class="btn ${approve ? 'primary' : 'danger'}" type="button" id="accessDecisionBtn" onclick="confirmAccountDecision(${requestId}, '${action}')">${approve ? 'Aprovar acesso' : 'Recusar acesso'}</button>`
  );
};

window.confirmAccountDecision = async function (requestId, action) {
  const button = document.getElementById('accessDecisionBtn');
  if (button) {
    button.disabled = true;
    button.textContent = 'Registrando…';
  }
  const item = (typeof accountRequestsCache !== 'undefined' ? accountRequestsCache : []).find(
    (r) => Number(r.id) === Number(requestId)
  );
  try {
    const response = await fetch('/api/account-requests/action', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id: Number(requestId), action }),
    });
    const result = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(result.error || 'Não foi possível registrar a decisão.');
    closeModal();
    if (typeof window.loadAccountRequests === 'function') await window.loadAccountRequests();
    notify(`Acesso de ${item?.name || 'a pessoa'} ${action === 'approve' ? 'aprovado' : 'recusado'}.`);
  } catch (error) {
    closeModal();
    if (typeof window.loadAccountRequests === 'function') await window.loadAccountRequests();
    notify(`Erro ao registrar a decisão: ${error.message}`);
  }
};

/* ---- Acesso às obras por usuário (somente visualizar / visualizar e editar) ---- */
window.setObrasAccess = async function (requestId, access) {
  const id = Number(requestId);
  if (!Number.isSafeInteger(id) || id < 1 || !['visualizar', 'editar'].includes(access)) {
    notify('Usuário ou permissão inválida. Atualize a lista e tente novamente.');
    return;
  }
  const cache = typeof accountRequestsCache !== 'undefined' ? accountRequestsCache : [];
  const item = cache.find((r) => Number(r.id) === id);
  if (!item) {
    notify('Usuário não encontrado. Atualize a lista e tente novamente.');
    return;
  }
  const previous = item.obras_access === 'editar' ? 'editar' : 'visualizar';
  if (previous === access) return;
  const select = document.querySelector(`select[data-request="${id}"]`);
  if (select) select.disabled = true;
  try {
    const response = await fetch('/api/account-requests/obras-access', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id, access }),
    });
    const result = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(result.error || 'Não foi possível alterar a permissão.');
    item.obras_access = access;
    notify(
      `${item.name || 'Usuário'}: ${access === 'editar' ? 'pode visualizar e editar as obras' : 'somente visualiza as obras'}.`
    );
  } catch (error) {
    item.obras_access = previous;
    notify(`Erro ao alterar a permissão: ${error.message}`);
  } finally {
    if (typeof renderAccountRequests === 'function') renderAccountRequests();
  }
};

// Seleção de projetos ao lado da permissão já existente.
function projectAccessControl(item) {
 const all=item.project_scope==='all', ids=item.project_ids||[];
 return `<div class="access-projects"><small>Projetos permitidos</small><button type="button" class="btn" onclick="openProjectAccess(${Number(item.id)})">${all?'Todos os projetos':ids.length+' projeto(s) selecionado(s)'} <span aria-hidden="true">⌄</span></button></div>`;
}
window.openProjectAccess=function(id){
 const item=accountRequestsCache.find(x=>Number(x.id)===Number(id));if(!item)return;
 const all=item.project_scope==='all',ids=item.project_ids||[];
 modal('Projetos que o usuário pode acessar',projectScopeMarkup(db.projects,all,ids),`<button class="btn" onclick="closeModal()">Cancelar</button><button class="btn primary" id="saveProjectAccess" onclick="saveProjectAccess(${id})">Salvar acesso</button>`);
};
window.toggleProjectChoices=function(){document.getElementById('projectChoices').hidden=new FormData(document.getElementById('projectScopeForm')).get('scope')==='all'};
window.saveProjectAccess=async function(id){
 const f=new FormData(document.getElementById('projectScopeForm')),scope=f.get('scope'),ids=f.getAll('project_ids');const b=document.getElementById('saveProjectAccess');b.disabled=true;
 try{const res=await fetch('/api/account-requests/project-access',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({id,scope,project_ids:scope==='all'?[]:ids})});const d=await res.json();if(!res.ok)throw Error(d.error);const item=accountRequestsCache.find(x=>Number(x.id)===Number(id));item.project_scope=scope;item.project_ids=scope==='all'?[]:ids;closeModal();renderAccountRequests();notify('Acesso aos projetos atualizado.');}catch(e){document.getElementById('projectScopeError').textContent=e.message;b.disabled=false}
};

function projectScopeMarkup(projects,all,ids){return `<p>Selecione um, vários ou todos os projetos. A permissão de visualizar ou editar continua sendo a definida ao lado.</p><form id="projectScopeForm"><fieldset class="project-scope-modes"><label><input type="radio" name="scope" value="all" ${all?'checked':''} onchange="toggleProjectChoices()"> Todos os projetos <small>Inclui novos projetos criados depois.</small></label><label><input type="radio" name="scope" value="selected" ${!all?'checked':''} onchange="toggleProjectChoices()"> Projetos selecionados</label></fieldset><div id="projectChoices" class="project-choices" ${all?'hidden':''}>${projects.length?projects.map(p=>`<label><input type="checkbox" name="project_ids" value="${esc(p.id)}" ${ids.includes(p.id)?'checked':''}><span>${esc(p.name||p.nome||'Projeto')}</span></label>`).join(''):'<p>Nenhum projeto cadastrado.</p>'}</div><p id="projectScopeError" role="status"></p></form>`;}
