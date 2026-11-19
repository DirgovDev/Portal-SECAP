/* records-cards.js — alternância Tabela / Cards na lista de obras de cada projeto. */
(function () {
  'use strict';
  var KEY = 'secap-records-view';
  window.recordsView = 'table';
  try { if (localStorage.getItem(KEY) === 'cards') window.recordsView = 'cards'; } catch (e) {}

  window.setRecordsView = function (mode) {
    window.recordsView = mode === 'cards' ? 'cards' : 'table';
    try { localStorage.setItem(KEY, window.recordsView); } catch (e) {}
    render();
  };

  /* 1) botões de alternância no cabeçalho do painel "Obras e registros" */
  var viewBefore = projectView;
  projectView = function () {
    var html = viewBefore();
    var on = function (m) { return window.recordsView === m ? ' is-on' : ''; };
    var toggle =
      '<div class="view-toggle" role="group" aria-label="Formato de exibição das obras">' +
      '<button type="button" class="' + on('table').trim() + '" aria-pressed="' + (window.recordsView === 'table') + '" onclick="setRecordsView(\'table\')">' + icon('sheet') + ' Tabela</button>' +
      '<button type="button" class="' + on('cards').trim() + '" aria-pressed="' + (window.recordsView === 'cards') + '" onclick="setRecordsView(\'cards\')">' + icon('dashboard') + ' Cards</button></div>';
    return '<div class="municipal-project-detail">'+html.replace('<h2>Obras e registros</h2>', '<h2>Obras e registros</h2>' + toggle)+'</div>';
  };

  /* 2) quando o formato é "cards", a lista de obras é desenhada como cards */
  var tableBefore = table;
  table = function (rs, limited) {
    if (window.recordsView !== 'cards' || limited || !projectId || !rs.length) { const html=tableBefore.apply(this, arguments); return projectId&&!limited?sheetMarkup(html):html; }
    var p = visible().find(function (x) { return x.id === projectId; });
    if (!p) return tableBefore.apply(this, arguments);
    var shown = rs.slice(0, tableLimit);
    return '<div class="rcards">' + shown.map(function (r) { return card(r, p); }).join('') + '</div>' +
      '<div class="tablefoot"><span>' + shown.length + ' de ' + rs.length + ' obras</span>' +
      (rs.length > tableLimit
        ? '<button class="textbtn" onclick="showMoreRows()">Mostrar mais ' + Math.min(50, rs.length - tableLimit) + ' obras</button>'
        : '<span>Clique em um card para abrir a obra</span>') + '</div>';
  };

  function sheetMarkup(html){
    const t=document.createElement('template');t.innerHTML=html;const grid=t.content.querySelector('table');if(!grid)return html;
    grid.classList.add('records-sheet');grid.setAttribute('aria-label','Obras: use as setas para navegar nas células. Abra pelo nome da obra.');
    // The redundant action column is removed: only the first column opens a record.
    const last=grid.querySelector('thead tr')?.lastElementChild;if(last?.textContent.trim()==='Ações'){last.remove();grid.querySelectorAll('tbody tr').forEach(r=>r.lastElementChild.remove())}
    grid.querySelectorAll('tbody td').forEach((cell,i)=>{cell.tabIndex=i===0?0:-1});
    const hint=t.content.querySelector('.tablefoot');if(hint){const h=document.createElement('span');h.className='sheet-hint';h.textContent='Clique em uma célula e use ← ↑ ↓ →. Para abrir a obra, clique no nome.';hint.append(h)}
    return t.innerHTML;
  }
  function selectCell(cell){const grid=cell.closest('.records-sheet');grid.querySelectorAll('td[tabindex="0"]').forEach(e=>e.tabIndex=-1);cell.tabIndex=0;cell.focus({preventScroll:true});if(cell.scrollIntoView)cell.scrollIntoView({block:'nearest',inline:'nearest'});
    // A coluna fixa cobre células à esquerda; scrollIntoView não desconta essa área.
    let viewport=grid.parentElement;
    while(viewport&&viewport!==document.body){const style=getComputedStyle(viewport);if(/auto|scroll/.test(style.overflowX)&&viewport.scrollWidth>viewport.clientWidth+1)break;viewport=viewport.parentElement}
    if(!viewport||viewport===document.body)return;
    if(cell.cellIndex===0){viewport.scrollLeft=0;return}
    const first=cell.parentElement.cells[0],fixed=getComputedStyle(first).position==='sticky'?first.getBoundingClientRect().width:0;
    const frame=viewport.getBoundingClientRect(),box=cell.getBoundingClientRect(),left=frame.left+viewport.clientLeft+fixed+8,right=frame.left+viewport.clientLeft+viewport.clientWidth-8;
    if(box.width>right-left){viewport.scrollLeft+=box.left-left}else if(box.left<left){viewport.scrollLeft-=left-box.left}else if(box.right>right){viewport.scrollLeft+=box.right-right}
    viewport.scrollLeft=Math.max(0,Math.min(viewport.scrollLeft,viewport.scrollWidth-viewport.clientWidth));}
  document.addEventListener('click',function(e){const cell=e.target.closest('.records-sheet tbody td');if(!cell)return;selectCell(cell);if(cell.cellIndex>0){e.preventDefault();e.stopPropagation()}},true);
  document.addEventListener('keydown',function(e){const cell=e.target.closest('.records-sheet tbody td');if(!cell||e.altKey||e.ctrlKey||e.metaKey||e.shiftKey)return;const offsets={ArrowLeft:[0,-1],ArrowRight:[0,1],ArrowUp:[-1,0],ArrowDown:[1,0]};const delta=offsets[e.key];if(!delta)return;e.preventDefault();e.stopPropagation();const rows=cell.parentElement.parentElement.rows,row=cell.parentElement.sectionRowIndex;const next=rows[row+delta[0]]?.cells[cell.cellIndex+delta[1]];if(next)selectCell(next)},true);
  function cardValue(r,p,id,label,semantic){const f=p.fields.find(f=>f.id===id)||p.fields.find(f=>String(f.name).normalize('NFD').replace(/[\u0300-\u036f]/g,'').trim().toLowerCase()===label);const v=(semantic?val(r,p,semantic):undefined)??r[f?.id||id];return v==null||v===''?'—':String(v)}
  function card(r,p){
    const status=canonicalStatus(val(r,p,'status')||r.status),title=recordTitle(r,p);
    const fields=[['ID',cardValue(r,p,'codigo','id')],['Órgão responsável',cardValue(r,p,'orgao','orgao responsavel','agency')],['Macroetapa',cardValue(r,p,'etapa','macroetapa','stage')],['Prioridade',cardValue(r,p,'prioridade','prioridade','priority')]];
    const open="editRecord('"+esc(p.id)+"','"+esc(r.id)+"')";
    // A cor do topo do card acompanha a cor do status da obra.
    const chip=badge(status),tint=(/--status-color:([^;"]+)/.exec(chip)||[])[1]||'#0a7cc1';
    return '<article class="rcard municipal-work-card" style="--wc:'+esc(tint)+'" tabindex="0" role="button" aria-label="Abrir '+esc(title)+'" onclick="'+open+'" onkeydown="if(event.key===\'Enter\'||event.key===\' \'){event.preventDefault();'+open+'}">'+'<div class="work-card-band"><div class="work-card-heading"><h3>'+esc(title)+'</h3></div></div><div class="rc-grid">'+fields.map(([label,value])=>'<div class="rc-item"><span>'+label+'</span><b>'+esc(value)+'</b></div>').join('')+'</div><footer class="rc-foot"><span class="work-card-status">'+chip+'</span><span class="rc-open">Abrir obra'+icon('arrow')+'</span></footer></article>';
  }
})();
