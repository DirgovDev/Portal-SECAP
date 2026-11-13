/* search-suggest.js — sugestões em todas as barras de pesquisa.
   Ao digitar, aparece uma lista de obras/projetos/compromissos que combinam com o texto;
   ao clicar (ou Enter) na sugestão, o item é aberto. */
(function () {
  'use strict';
  var MAX = 8;
  var box, current = null, items = [], active = -1, lastKey = '';

  /* ---------- utilidades ---------- */
  function norm(s) {   /* sem acentos e minúsculo, mantendo o mesmo tamanho do texto */
    return String(s == null ? '' : s).split('').map(function (c) {
      var b = c.normalize('NFD').replace(/[\u0300-\u036f]/g, '');
      return (b[0] || c).toLowerCase();
    }).join('');
  }
  function hayOf(r, extra) {
    var out = [extra || ''];
    for (var k in r) { var v = r[k]; if (v != null && typeof v !== 'object' && typeof v !== 'function') out.push(v); }
    return norm(out.join(' '));
  }
  function score(title, hay, tokens, q) {
    for (var i = 0; i < tokens.length; i++) if (hay.indexOf(tokens[i]) < 0) return null;
    var t = norm(title);
    return t.indexOf(q) === 0 ? 0 : t.indexOf(q) > 0 ? 1 : 2;
  }
  function mark(title, q) {
    var t = norm(title), i = t.indexOf(q);
    if (i < 0 || !q) return esc(title);
    return esc(title.slice(0, i)) + '<mark>' + esc(title.slice(i, i + q.length)) + '</mark>' + esc(title.slice(i + q.length));
  }
  function userProjects() { return typeof visible === 'function' ? visible() : []; }

  /* ---------- fontes de sugestão ---------- */
  function recordItems(projects, q, tokens) {
    var out = [];
    projects.forEach(function (p) {
      (p.records || []).forEach(function (r) {
        var title = recordTitle(r, p), s = score(title, hayOf(r, p.name), tokens, q);
        if (s === null) return;
        out.push({ s: s, kind: 'obra', title: title, sub: p.name + (r.status ? ' · ' + r.status : ''), icon: 'file',
          run: function () { editRecord(p.id, r.id); } });
      });
    });
    return out;
  }
  function projectItems(q, tokens, open) {
    var out = [];
    userProjects().forEach(function (p) {
      var s = score(p.name || '', norm([p.name, p.description, p.owner].join(' ')), tokens, q);
      if (s === null) return;
      out.push({ s: s, kind: 'projeto', title: p.name || 'Projeto', sub: (p.records || []).length + ' obras' + (p.owner ? ' · ' + p.owner : ''),
        icon: 'folder', run: function () { open(p.id); } });
    });
    return out;
  }
  function sorted(list) { return list.sort(function (a, b) { return a.s - b.s || a.title.localeCompare(b.title, 'pt-BR'); }); }

  var SOURCES = {
    'Buscar projetos': function (q, t) { return sorted(projectItems(q, t, function (id) { go('projects', id); })); },
    'Buscar painéis': function (q, t) { return sorted(projectItems(q, t, function (id) { openBI(id); })); },
    'Buscar obras': function (q, t) {
      var p = userProjects().filter(function (x) { return x.id === projectId; });
      return sorted(recordItems(p, q, t));
    },
    'Buscar no BI': function (q, t) {
      var p = userProjects().filter(function (x) { return x.id === biProject; });
      return sorted(recordItems(p, q, t));
    },
    'Buscar': function (q, t) {
      var pr = sorted(projectItems(q, t, function (id) { go('projects', id); })).slice(0, 3);
      return pr.concat(sorted(recordItems(userProjects(), q, t))).slice(0, MAX);
    },
    '#agendaSearch': function (q, t) {
      var day = agendaEvents().filter(function (e) { return e.date === openedAgendaDay; }), out = [];
      day.forEach(function (e, i) {
        var title = e.title || (e.personal && e.personal.title) || (e.r && e.r.nome) || 'Compromisso';
        var s = score(title, norm(title + ' ' + (e.field || '') + ' ' + ((e.r && e.r.status) || '')), t, q);
        if (s === null) return;
        out.push({ s: s, kind: e.personal ? 'lembrete' : 'obra', title: title, sub: e.personal ? (e.field || 'Lembrete') : (e.field || (e.r && e.r.status) || 'Prazo da obra'),
          icon: 'calendar', run: function () { openAgendaEntry(i); } });
      });
      return sorted(out);
    }
  };
  function keyOf(el) { return el.id === 'agendaSearch' ? '#agendaSearch' : el.getAttribute('aria-label') || ''; }
  function sourceFor(el) { return el && el.tagName === 'INPUT' ? SOURCES[keyOf(el)] : null; }

  /* ---------- caixa de sugestões ---------- */
  function ensureBox() {
    if (box) return box;
    box = document.createElement('div');
    box.id = 'search-suggest'; box.setAttribute('role', 'listbox'); box.hidden = true;
    box.addEventListener('mousedown', function (ev) {
      var li = ev.target.closest('[data-i]');
      ev.preventDefault();                      /* mantém o foco na barra */
      if (li) choose(+li.getAttribute('data-i'));
    });
    document.body.appendChild(box);
    return box;
  }
  function hide() {
    if (box) box.hidden = true;
    if (current) current.setAttribute('aria-expanded', 'false');
    items = []; active = -1;
  }
  function position() {
    if (!box || box.hidden || !current) return;
    var host = current.closest('.search') || current, r = host.getBoundingClientRect();
    var w = Math.max(r.width, 340), left = Math.min(r.left, window.innerWidth - w - 8);
    box.style.left = Math.max(8, left) + 'px';
    box.style.top = r.bottom + 6 + 'px';
    box.style.width = Math.min(w, window.innerWidth - 16) + 'px';
  }
  function paint(q) {
    var b = ensureBox();
    if (!items.length) {
      b.innerHTML = '<div class="sg-empty">Nenhuma sugestão para “' + esc(q) + '”</div>';
    } else {
      b.innerHTML = items.map(function (it, i) {
        return '<div class="sg-item' + (i === active ? ' is-active' : '') + '" role="option" id="sg-' + i + '" data-i="' + i + '" aria-selected="' + (i === active) + '">' +
          '<span class="sg-ico">' + icon(it.icon) + '</span><span class="sg-text"><b>' + mark(it.title, q) + '</b><small>' + esc(it.sub) + '</small></span>' +
          '<span class="sg-kind">' + it.kind + '</span></div>';
      }).join('') + '<div class="sg-hint"><span>↑ ↓ navegar</span><span>Enter abrir</span><span>Esc fechar</span></div>';
    }
    b.hidden = false;
    if (current) current.setAttribute('aria-expanded', 'true');
    position();
  }
  function refresh(input) {
    var src = sourceFor(input); if (!src) return hide();
    current = input; lastKey = keyOf(input);
    input.setAttribute('aria-autocomplete', 'list'); input.setAttribute('aria-controls', 'search-suggest');
    var raw = input.value.trim();
    if (!raw) return hide();
    var q = norm(raw), tokens = q.split(/\s+/).filter(Boolean);
    try { items = src(q, tokens).slice(0, MAX); } catch (e) { console.error('Sugestões:', e); items = []; }
    active = -1;
    paint(q);
  }
  function choose(i) {
    var it = items[i]; if (!it) return;
    hide();
    try { if (typeof closeModal === 'function' && document.getElementById('agendaSearch')) closeModal(); it.run(); }
    catch (e) { console.error(e); }
  }
  function move(delta) {
    if (!items.length) return;
    active = (active + delta + items.length) % items.length;
    box.querySelectorAll('.sg-item').forEach(function (n, i) {
      n.classList.toggle('is-active', i === active); n.setAttribute('aria-selected', String(i === active));
      if (i === active) n.scrollIntoView({ block: 'nearest' });
    });
    if (current) current.setAttribute('aria-activedescendant', 'sg-' + active);
  }

  /* ---------- eventos ---------- */
  document.addEventListener('input', function (ev) { if (sourceFor(ev.target)) refresh(ev.target); }, true);
  document.addEventListener('focusin', function (ev) {
    if (sourceFor(ev.target) && ev.target.value.trim()) refresh(ev.target);
  });
  document.addEventListener('keydown', function (ev) {
    if (!box || box.hidden || ev.target !== current && !(current && !document.body.contains(current))) return;
    if (ev.key === 'ArrowDown') { ev.preventDefault(); move(1); }
    else if (ev.key === 'ArrowUp') { ev.preventDefault(); move(-1); }
    else if (ev.key === 'Enter' && active >= 0) { ev.preventDefault(); ev.stopPropagation(); choose(active); }
    else if (ev.key === 'Escape') { ev.stopPropagation(); hide(); }
  }, true);
  document.addEventListener('mousedown', function (ev) {
    if (box && !box.hidden && !box.contains(ev.target) && ev.target !== current) hide();
  });
  window.addEventListener('resize', position);
  window.addEventListener('scroll', position, true);

  /* A tela é redesenhada a cada tecla: reencontra a barra e mantém a lista ancorada. */
  var pending;
  new MutationObserver(function () {
    clearTimeout(pending);
    pending = setTimeout(function () {
      if (!box || box.hidden) return;
      if (current && document.body.contains(current)) return position();
      var again = lastKey && Array.prototype.find.call(document.querySelectorAll('input'), function (i) { return keyOf(i) === lastKey; });
      if (again) { current = again; position(); } else hide();
    }, 60);
  }).observe(document.body, { childList: true, subtree: true });
})();
