/* field-rename.js — permite renomear o campo direto na janela "Editar dados".
   Não altera os dados já preenchidos: o campo é identificado por um id interno,
   então só o nome exibido muda (em todas as obras do mesmo projeto). */
(function () {
  'use strict';
  if (typeof openRecordForm !== 'function') return;
  var original = openRecordForm;

  openRecordForm = function (pid, rid) {
    original.apply(this, arguments);
    try {
      addRenameControls(pid);
    } catch (e) {
      console.error('Renomear campo:', e);
    }
  };

  function addRenameControls(pid) {
    // Renomear altera a estrutura do projeto; permissões de campo liberam
    // somente valores dos registros, nunca a edição do esquema.
    if (typeof canManage !== 'function' || !canManage()) return;
    var p = db.projects.find(function (x) {
      return x.id === pid;
    });
    if (!p || !canEdit(p)) return;
    document.querySelectorAll('#recordForm .field').forEach(function (box) {
      var control = box.querySelector('[name]');
      var label = box.querySelector('label');
      if (!control || !label || label.querySelector('.rename-field')) return;
      var f = p.fields.find(function (x) {
        return x.id === control.getAttribute('name');
      });
      if (!f) return;
      renderLabel(label, f, control, p);
    });
  }

  function renderLabel(label, f, control, p) {
    label.innerHTML =
      '<span class="field-name">' +
      esc(f.name) +
      (f.required ? ' *' : '') +
      '</span>' +
      '<button type="button" class="rename-field" title="Renomear campo" aria-label="Renomear o campo ' +
      esc(f.name) +
      '">' +
      icon('edit') +
      '</button>';
    label.querySelector('.rename-field').addEventListener('click', function (ev) {
      ev.preventDefault();
      startEdit(label, f, control, p);
    });
  }

  function startEdit(label, f, control, p) {
    label.innerHTML =
      '<span class="rename-box"><input type="text" class="rename-input" maxlength="80" value="' +
      esc(f.name) +
      '" aria-label="Novo nome do campo">' +
      '<button type="button" class="rename-ok" title="Salvar nome" aria-label="Salvar nome">' +
      icon('check') +
      '</button>' +
      '<button type="button" class="rename-cancel" title="Cancelar" aria-label="Cancelar">' +
      icon('close') +
      '</button></span>';
    var input = label.querySelector('.rename-input');
    input.focus();
    input.select();

    function cancel() {
      renderLabel(label, f, control, p);
    }
    function save() {
      var name = input.value.trim();
      if (!name) {
        input.focus();
        return notify('O nome do campo não pode ficar vazio.');
      }
      if (name === f.name) return cancel();
      var dup = p.fields.some(function (x) {
        return x.id !== f.id && x.name.trim().toLowerCase() === name.toLowerCase();
      });
      if (dup) {
        input.focus();
        return notify('Já existe um campo com esse nome neste projeto.');
      }
      var before = f.name;
      f.name = name;
      persist('Renomeou campo', p, before, name);
      control.setAttribute('aria-label', name);
      renderLabel(label, f, control, p);
      render(); /* atualiza tabelas, fichas e filtros por trás da janela */
      notify('Nome do campo atualizado em todas as obras deste projeto.');
    }
    label.querySelector('.rename-ok').addEventListener('click', save);
    label.querySelector('.rename-cancel').addEventListener('click', cancel);
    input.addEventListener('keydown', function (ev) {
      if (ev.key === 'Enter') {
        ev.preventDefault();
        ev.stopPropagation();
        save();
      } else if (ev.key === 'Escape') {
        ev.preventDefault();
        ev.stopPropagation();
        cancel();
      }
    });
  }
})();
