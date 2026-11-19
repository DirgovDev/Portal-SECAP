/* dashboard-v2.js — Nova "Visão geral": indicadores, pontos de atenção e gráficos.
   Substitui apenas a função dashboard(); dados e demais telas não são alterados. */
(function () {
  'use strict';
  var PAL = ['#f37021', '#002f47', '#169dc4', '#194621', '#97b0bf', '#fff200', '#b4a0c6'];
  var live = [];
  var renderGeneration=0;
  var statusSelected={};

  function rowsOf(projects) {
    var out = [];
    projects.forEach(function (p) {
      (p.records || []).forEach(function (r) {
        out.push({ r: r, p: p });
      });
    });
    return out;
  }
  function info(x) {
    var r = x.r,
      p = x.p;
    var status = canonicalStatus(val(r,p,'status')); 
    var finished = isFinished(r, p);
    var cancelled = /cancel/i.test(status);
    var deadline = val(r, p, 'deadline');
    var dl = deadline ? daysLeft(deadline) : null;
    var late = (!!deadline&&dl<0||status==='Atrasado')&&!finished&&!cancelled;
    var owner=String(val(r,p,'owner')||'').trim();
    var lastEdit=editedAt(r);
    var idleDays=lastEdit?Math.floor((Date.now()-lastEdit.getTime())/86400000):null;
    if(/^(?:não informado|nao informado|a definir|não definido|nao definido|n\/a|-)$/i.test(owner))owner='';
    return {
      x: x,
      status: status || 'Não informado',
      finished: finished,
      cancelled: cancelled,
      paralyzed: /paralis/i.test(status),
      running: /andamento|execu/i.test(status) && !finished,
      late: late,
      daysLate: late&&dl<0?-dl:0,
      attention:status==='Ponto de Atenção'&&!finished&&!cancelled,
      noOwner: !owner && !finished && !cancelled,
      stale: !!r.atualizado_em && daysLeft(r.atualizado_em) < -30 && !finished && !cancelled,
      budget: numberOrNull(val(r, p, 'budget')),
      progress: physicalProgress(val(r,p,'progress')),
      agency: String(val(r, p, 'agency') || '').trim(),
      title: recordTitle(r, p),
      lastEdit: lastEdit,
      idleDays: idleDays,
      // Obra sem nenhuma alteração há mais de 10 dias (concluídas e canceladas não entram).
      idle: idleDays!==null&&idleDays>IDLE_DAYS&&!finished&&!cancelled,
    };
  }
  var IDLE_DAYS=10;
  // Data da última alteração da obra (gravada pelo banco a cada salvamento).
  function editedAt(r){var t=r&&(r.updated_at||r.created_at);var d=t?new Date(t):null;return d&&!isNaN(d.getTime())?d:null}
  function dateTime(d){return d?d.toLocaleString('pt-BR',{day:'2-digit',month:'2-digit',year:'numeric',hour:'2-digit',minute:'2-digit'}):'—'}
  function idleText(n){return 'Sem alteração há '+n+(n===1?' dia':' dias')}
  function reasons(i) {
    var a = [];
    if (i.late)
      a.push(['late',i.daysLate>0?'Atrasada há '+i.daysLate+(i.daysLate===1?' dia':' dias'):'Marcada como atrasada · confira o prazo']);
    if(i.attention)a.push(['stop','Ponto de Atenção']);
    if (i.paralyzed) a.push(['stop', 'Paralisada']);
    
    if (i.stale) a.push(['stale', 'Sem atualização há mais de 30 dias']);
    return a;
  }
  function score(i) {
    return (
      (i.late ? 100 + i.daysLate : 0) +
      (i.paralyzed ? 80 : 0) + (i.attention?60:0) +
      0
    );
  }

  window.dashboard = function () {
    var generation=++renderGeneration;
    var projects = (typeof visible==='function'?visible():db.projects||[]);
    var all = rowsOf(projects).map(info);
    var active = all.filter(function (i) {
      return !i.cancelled;
    });
    var cnt = function (f) {
      return all.filter(f).length;
    };
    var done = cnt(function (i) {
      return i.finished;
    });
    var late = cnt(function (i) {
      return i.late;
    });
    var stopped = cnt(function (i) {
      return i.paralyzed;
    });
    var noOwner = cnt(function (i) {
      return i.noOwner;
    });
    var running = cnt(function (i) {
      return i.running;
    });
    var invest = active.reduce(function (s, i) {
      return s + (i.budget || 0);
    }, 0);
    var prog = active.filter(function (i) {
      return i.progress !== null;
    });
    var avgProg = prog.length
      ? Math.round(
          prog.reduce(function (s, i) {
            return s + i.progress;
          }, 0) / prog.length * 10
        ) / 10
      : 0;
    var attention = all
      .filter(function (i) {
        return i.idle;
      })
      .sort(function (a, b) {
        return b.idleDays - a.idleDays || score(b) - score(a);
      });
    var pct = function (n) {
      return all.length ? Math.round((n / all.length) * 100) + '% do total' : '—';
    };

    var kpis = [
      [
        'all',
        'folder',
        'Total de obras',
        all.length,
        projects.length + (projects.length === 1 ? ' projeto' : ' projetos'),
        'navy',
      ],
      ['running', 'kanban', 'Em andamento', running, pct(running), 'cyan'],
      ['done', 'check', 'Concluídas', done, pct(done), 'green'],
      [
        'stopped',
        'alert',
        'Paralisadas',
        stopped,
        stopped ? 'Exigem decisão' : 'Nenhuma no momento',
        'red',
      ],
      ['late', 'calendar', 'Atrasadas', late, late?'Prazo vencido ou atraso informado':all.length?'Sem atraso identificado':'Sem obras cadastradas', 'orange'],
      [
        'attention',
        'alert',
        'Ponto de atenção',
        cnt(function(i){return i.status==='Ponto de Atenção';}),
        'Situação informada nos registros',
        'orange',
      ],
      [
        null,
        'chart',
        'Avanço físico médio',
        !prog.length?'Sem medição':prog.length<active.length?'Dados parciais':avgProg+'%',
        prog.length+' de '+active.length+' não canceladas com medição'+(prog.length?' · média informada: '+avgProg.toLocaleString('pt-BR')+'%':''),
        'green',
        prog.length===active.length&&prog.length?avgProg:undefined,
      ],
      [null,'clock','Informação mais recente',execRecentDate(rowsOf(projects))?date(execRecentDate(rowsOf(projects))):'Não informada','Conferir registros sem atualização','navy'],
    ];
    var kpiHtml = kpis
      .map(function (k) {
        var tag = k[0] ? 'button type="button" onclick="dashOpen(\'' + k[0] + '\')"' : 'div';
        var close = k[0] ? 'button' : 'div';
        return (
          '<' +
          tag +
          ' class="dkpi ' +
          k[5] +
          (k[0] ? ' is-link' : '') +
          '"><span class="dkpi-ico">' +
          icon(k[1]) +
          '</span>' +
          '<span class="dkpi-label">' +
          k[2] +
          '</span><span class="dkpi-num">' +
          k[3] +
          '</span>' +
          (k[6] !== undefined
            ? '<span class="dkpi-bar"><i style="width:' + Math.min(100, k[6]) + '%"></i></span>'
            : '') +
          '<span class="dkpi-sub">' +
          k[4] +
          '</span></' +
          close +
          '>'
        );
      })
      .join('');

    var top = attention.slice(0, 8);
    var attHtml = top.length
      ? top
          .map(function (i) {
            return (
              '<li class="att-row"><div class="att-main"><b>' +
              esc(i.title) +
              '</b><small>' +
              esc(i.x.p.name || '') +
              (i.agency ? ' · ' + esc(i.agency) : '') +
              '</small><span class="att-tags">' +
              [['stale',idleText(i.idleDays)]].concat(reasons(i).filter(function(t){return t[0]!=='stale'}))
                .map(function (t) {
                  return '<span class="att-tag ' + t[0] + '">' + esc(t[1]) + '</span>';
                })
                .join('') +
              '</span><small class="att-next-action">Última alteração: '+esc(dateTime(i.lastEdit))+' · '+esc(i.x.r.proxima||'Definir a próxima providência')+'</small></div><button type="button" class="btn" onclick="editRecord(\'' +
              esc(i.x.p.id) +
              "','" +
              esc(i.x.r.id) +
              '\')">Abrir ' +
              icon('arrow') +
              '</button></li>'
            );
          })
          .join('')
      : '<li class="att-empty">' +
        icon('check') +
        (all.length?'<b>Nenhuma obra parada</b><small>Todas as obras em acompanhamento foram alteradas nos últimos '+IDLE_DAYS+' dias.</small></li>':'<b>Ainda não há obras</b><small>Cadastre ou importe os registros para iniciar a análise.</small></li>');

    setTimeout(function () {
      if(generation===renderGeneration&&tab==='dashboard'){drawCharts(projects,all);if(isSysAdmin())loadRecentEditors(generation);}
    }, 80);

    var d = new Date().toLocaleDateString('pt-BR', {
      weekday: 'long',
      day: 'numeric',
      month: 'long',
    });
    return (
      head(
        'PORTAL SECAP · ' + d.toUpperCase(),
        'Visão geral',
        attention.length
          ? attention.length +
              (attention.length === 1 ? ' obra está' : ' obras estão') +
              ' sem alteração há mais de '+IDLE_DAYS+' dias.'
          : all.length?'Todas as obras em acompanhamento foram alteradas nos últimos '+IDLE_DAYS+' dias.':'Cadastre projetos e obras para começar o acompanhamento.'
      ) +
      
      '<section class="dkpis" aria-label="Indicadores">' +
      kpiHtml +
      '</section>' +
      
      '<div class="dgrid"><section class="panel"><div class="panelhead"><div><h2>Prazos e decisões pendentes</h2><small>' +
      (attention.length > 8
        ? 'As 8 paradas há mais tempo, de ' + attention.length + ' sem alteração há mais de ' + IDLE_DAYS + ' dias'
        : 'Obras sem alteração há mais de ' + IDLE_DAYS + ' dias') +
      '</small></div>' +
      (attention.length
        ? '<button class="textbtn" onclick="dashOpen(\'attention\')">Ver todas</button>'
        : '') +
      '</div>' +
      '<ul class="att-list">' +
      attHtml +
      '</ul></section>' +
      '<section class="panel"><div class="panelhead"><div><h2>Obras por situação</h2><small>Status informado nas obras</small></div></div>' +
      '<div class="panelbody"><div id="dashStatus" class="dchart" style="height:300px"></div></div></section></div>' +
      
      '<div class="dgrid" style="grid-template-columns:1fr">' +
      (isSysAdmin() ? recentEditorsPanel() : recentObrasPanel(all)) +
      '</div>'
    );
  };

  function openBtn(pid,rid){return '<button type="button" class="btn" onclick="editRecord(\''+esc(pid)+"','"+esc(rid)+'\')">Abrir '+icon('arrow')+'</button>'}

  // Usuário: obras editadas mais recentemente, com data e hora.
  function recentObrasPanel(all){
    var list=all.filter(function(i){return i.lastEdit}).sort(function(a,b){return b.lastEdit-a.lastEdit}).slice(0,10);
    return '<section class="panel recent-panel"><div class="panelhead"><div><h2>Obras editadas recentemente</h2><small>As 10 alterações mais recentes, com data e hora</small></div></div>'+
      '<ul class="att-list recent-list">'+(list.length?list.map(function(i){
        return '<li class="att-row"><div class="att-main"><b>'+esc(i.title)+'</b><small>'+esc(i.x.p.name||'')+(i.agency?' · '+esc(i.agency):'')+'</small>'+
          '<span class="att-tags"><span class="att-tag recent">'+icon('clock')+' '+esc(dateTime(i.lastEdit))+'</span></span></div>'+openBtn(i.x.p.id,i.x.r.id)+'</li>';
      }).join(''):'<li class="att-empty">'+icon('clock')+'<b>Nenhuma edição registrada</b><small>As obras alteradas aparecerão aqui.</small></li>')+'</ul></section>';
  }

  // Administrador: quem editou recentemente, com as obras e o horário de cada edição.
  var editorsCache=null; // {at, data | error | loading}
  var EDITORS_DAYS=30;
  function recentEditorsPanel(){
    return '<section class="panel recent-panel"><div class="panelhead"><div><h2>Quem editou recentemente</h2><small>Usuários que registraram alterações nos últimos '+EDITORS_DAYS+' dias, com as obras editadas</small></div>'+
      '<button class="textbtn" onclick="go(\'history\')">Ver auditoria</button></div>'+
      '<div class="panelbody" id="dashEditors">'+editorsHtml()+'</div></section>';
  }
  function editorsHtml(){
    if(!editorsCache||editorsCache.loading&&!editorsCache.data)return '<p class="dash-editors-msg" role="status">Consultando a auditoria…</p>';
    if(editorsCache.error)return '<p class="dash-editors-msg">Não foi possível consultar quem editou: '+esc(editorsCache.error)+'</p>';
    var users=editorsCache.data||[];
    if(!users.length)return '<p class="dash-editors-msg">Nenhuma edição de usuário nos últimos '+EDITORS_DAYS+' dias.</p>';
    return '<div class="editor-grid">'+users.map(function(u){
      var obras=u.obras||[];
      return '<article class="editor-card"><header><span class="editor-avatar" aria-hidden="true">'+esc(initials(u.who))+'</span><div><b>'+esc(u.who||'Usuário')+'</b>'+
        '<small>Última edição: '+esc(dateTime(new Date(u.lastAt)))+'</small></div>'+
        '<span class="editor-count" title="Obras editadas no período">'+u.obrasCount+(u.obrasCount===1?' obra':' obras')+'</span></header>'+
        '<ul>'+obras.map(function(o){
          var cur=currentObra(o);
          return '<li><button type="button" data-actor="'+esc(u.actor||'')+'" data-record="'+esc(o.recordId)+'" data-project="'+esc(o.projectId)+'" data-who="'+esc(u.who||'Usuário')+'" onclick="openEditorChanges(this.dataset)" title="Ver o que foi alterado"><span>'+esc(cur.name)+'</span>'+
            '<small>'+esc(dateTime(new Date(o.at)))+' · '+o.changes+(o.changes===1?' campo alterado':' campos alterados')+'</small></button></li>';
        }).join('')+(u.obrasCount>obras.length?'<li class="editor-more">e mais '+(u.obrasCount-obras.length)+' obra(s) · veja na auditoria</li>':'')+'</ul></article>';
    }).join('')+'</div>';
  }
  // Clique numa obra do painel: mostra o detalhe do que esse usuário alterou nela
  // (campo, antes → depois, data/hora e justificativa), sem abrir a obra.
  function editorValue(v,present){
    if(present===false||v===null||v===undefined||v==='')return '—';
    return typeof v==='object'?JSON.stringify(v):String(v);
  }
  function editorReason(c){
    var reason=String(c.reason||'').trim();
    if(!reason||reason==='Não informada')return '';
    var map=typeof auditObraReasons==='function'?auditObraReasons(reason):null;
    if(map)return map.get(c.recordName)||'';
    return reason;
  }
  window.openEditorChanges=function(d){
    var o={projectId:d.project,recordId:d.record},cur=currentObra(o);
    var title='Alterações de '+(d.who||'usuário');
    var foot='<button class="btn" type="button" onclick="closeModal()">Fechar</button>'+
      '<button class="btn" type="button" onclick="closeModal();go(\'history\')">Ver auditoria</button>'+
      '<button class="btn primary" type="button" data-project="'+esc(d.project)+'" data-record="'+esc(d.record)+'" onclick="closeModal();editRecord(this.dataset.project,this.dataset.record)">Abrir obra</button>';
    var head='<p class="editor-detail-obra"><strong>'+esc(cur.name)+'</strong>'+(cur.project?'<br><small>'+esc(cur.project)+' · últimos '+EDITORS_DAYS+' dias</small>':'')+'</p>';
    modal(title,head+'<div id="editorChangesBody"><p class="dash-editors-msg" role="status">Consultando as alterações…</p></div>',foot);
    if(!d.actor||!window.sb){
      var el0=document.getElementById('editorChangesBody');
      if(el0)el0.innerHTML='<p class="dash-editors-msg">Detalhe indisponível. Aplique supabase/security/recent_editor_details.sql no banco.</p>';
      return;
    }
    window.sb.rpc('secap_recent_editor_changes',{p_actor:d.actor,p_record:d.record,p_days:EDITORS_DAYS}).then(function(res){
      var el=document.getElementById('editorChangesBody');if(!el)return;
      if(res.error){el.innerHTML='<p class="dash-editors-msg">Não foi possível consultar: '+esc(/secap_recent_editor_changes/.test(res.error.message||'')?'aplique supabase/security/recent_editor_details.sql no banco.':res.error.message)+'</p>';return}
      var rows=Array.isArray(res.data)?res.data:[];
      if(!rows.length){el.innerHTML='<p class="dash-editors-msg">Nenhuma alteração encontrada no período.</p>';return}
      el.innerHTML='<div class="editor-changes-scroll"><table class="audit-details-table editor-changes-table"><thead><tr><th>Data e hora</th><th>Campo</th><th>Antes</th><th>Depois</th><th>Justificativa</th></tr></thead><tbody>'+
        rows.map(function(c){
          var field=c.fieldId?(c.field||c.fieldId):(c.action||'Obra');
          var before=c.fieldId?editorValue(c.before,c.beforePresent):(c.beforePresent?'Dados da obra':'—');
          var after=c.fieldId?editorValue(c.after,c.afterPresent):(c.afterPresent?'Dados da obra':'—');
          var why=editorReason(c);
          return '<tr><td>'+esc(dateTime(new Date(c.at)))+'</td><td><strong>'+esc(field)+'</strong></td><td class="editor-before">'+esc(before)+'</td><td class="editor-after"><b>'+esc(after)+'</b></td><td>'+(why?esc(why):'<span class="editor-none">Não informada</span>')+'</td></tr>';
        }).join('')+'</tbody></table></div>';
    },function(e){var el=document.getElementById('editorChangesBody');if(el)el.innerHTML='<p class="dash-editors-msg">Não foi possível consultar: '+esc(String(e&&e.message||e))+'</p>'});
  };
  // Nome atual da obra (a auditoria guarda o nome da época da edição).
  function currentObra(o){
    var projects=typeof visible==='function'?visible():db.projects||[];
    var p=projects.find(function(x){return String(x.id)===String(o.projectId)});
    var r=p&&(p.records||[]).find(function(x){return String(x.id)===String(o.recordId)});
    return {name:r?recordTitle(r,p):(o.recordName||'Obra')+(p?' (excluída)':''),project:p?p.name:o.projectName};
  }
  function initials(name){var p=String(name||'?').trim().split(/\s+/);return ((p[0]||'?')[0]+(p.length>1?p[p.length-1][0]:'')).toUpperCase()}
  function loadRecentEditors(generation){
    var paint=function(){var el=document.getElementById('dashEditors');if(el)el.innerHTML=editorsHtml()};
    var fresh=editorsCache&&!editorsCache.error&&!editorsCache.loading&&Date.now()-editorsCache.at<60000;
    if(fresh||editorsCache&&editorsCache.loading)return paint();
    if(!window.sb){editorsCache={at:Date.now(),error:'conexão indisponível.'};return paint()}
    editorsCache={at:Date.now(),loading:true,data:editorsCache&&editorsCache.data};
    window.sb.rpc('secap_recent_editors',{p_days:EDITORS_DAYS,p_users:12,p_obras:6}).then(function(res){
      editorsCache=res.error?{at:Date.now(),error:/secap_recent_editors/.test(res.error.message||'')?'aplique supabase/security/recent_editors.sql no banco.':res.error.message}:{at:Date.now(),data:Array.isArray(res.data)?res.data:[]};
      if(tab==='dashboard')paint();
    },function(e){editorsCache={at:Date.now(),error:String(e&&e.message||e)};if(tab==='dashboard')paint()});
  }
  // Depois de salvar uma obra, a lista de quem editou é consultada de novo.
  window.addEventListener('secap:obra-saved',function(){if(editorsCache&&!editorsCache.loading)editorsCache.at=0});

  function empty(el, msg) {
    el.innerHTML = '<div class="dchart-empty">' + msg + '</div>';
  }
  function chartOn(id) {
    var el = document.getElementById(id);
    if (!el || typeof echarts === 'undefined') return null;
    var c = echarts.getInstanceByDom(el) || echarts.init(el);
    live.push(c);

    // Observa mudanças de tamanho no contêiner do gráfico (ex: ao abrir/fechar o menu)
    if (window.ResizeObserver && !el._resizeObserver) {
      el._resizeObserver = new ResizeObserver(function () {
        if (!c.isDisposed()) c.resize();
      });
      el._resizeObserver.observe(el);
    }

    return { el: el, c: c };
  }
  // Função para unificar nomes duplicados e remover códigos numéricos
  function normalizarStatus(status) {
    return canonicalStatus(status);
  }

  function drawCharts(projects, all) {
    var a = chartOn('dashStatus');
    if (a) {
      var m = {};
      all.forEach(function (i) {
        var st = normalizarStatus(i.status);
        m[st] = (m[st] || 0) + 1;
      });

      var data = Object.keys(m).map(function (k) {
        return {name:k,value:m[k],itemStyle:{color:statusColor(k)}};
      });

      var visibleStatusTotal=data.reduce(function(sum,item){return statusSelected[item.name]===false?sum:sum+item.value},0);
      if (!data.length) empty(a.el, 'Ainda não há obras cadastradas.');
      else {
        a.el.style.height=Math.max(340,260+data.length*30)+'px';a.c.resize();
        a.c.setOption(
          {
            color: ['#f37021', '#169dc4', '#002f47', '#194621', '#97b0bf', '#c93636', '#b4a0c6'],
            graphic:{type:'text',left:'center',id:'visibleStatusTotal',top:102,silent:true,style:{text:visibleStatusTotal+'\n'+(visibleStatusTotal===1?'obra':'obras'),textAlign:'center',fill:'#002f47',fontSize:18,fontWeight:700,lineHeight:24}},
            tooltip: { trigger: 'item', confine:true, formatter: '{b}: <b>{c} obras</b> ({d}%)' },
            legend: {
              type:'plain',
              selected:{...statusSelected},
              orient:'vertical',
              left:16,
              top:250,
              itemGap:10,
              itemWidth:16,itemHeight:16,
              itemStyle:{borderColor:'#94A3B8',borderWidth:1},
              formatter:function(name){return name+'  · '+m[name]+' '+(m[name]===1?'obra':'obras')},
              icon: 'circle',
              textStyle: { color: '#475569', fontSize:15,lineHeight:20 },
            },
            series: [
              {
                name: 'Situação',
                type: 'pie',
                radius:[67,100],
                center:['50%',122], // Sobe o círculo para afastar da legenda
                avoidLabelOverlap: true,
                itemStyle: { borderColor: '#fff', borderWidth: 2, borderRadius: 6 },

                label: {show:false},
                emphasis: {label:{show:false}},
                labelLine: { show: false },
                data: data,
              },
            ],
          },
          true
        );
        // Legend toggles change only the visible chart total, never the source data.
        a.c.off('legendselectchanged');
        a.c.on('legendselectchanged',function(event){
          statusSelected={...event.selected};
          var visibleTotal=data.reduce(function(sum,item){return event.selected[item.name]===false?sum:sum+item.value},0);
          a.c.setOption({graphic:{id:'visibleStatusTotal',style:{text:visibleTotal+'\n'+(visibleTotal===1?'obra':'obras')}}});
        });
      }
    }

    var b = chartOn('dashProgress');
    if (b) {
      var rows = projects.map(function (p) {
        var v = p.records
          .map(function (r) {
            return physicalProgress(val(r,p,'progress'));
          })
          .filter(function (n) {
            return n !== null;
          });
        return [
          p.name || 'Sem nome',
          v.length
            ? Math.round(
                v.reduce(function (s, n) {
                  return s + n;
                }, 0) / v.length
              )
            : null,
          v.length,p.records.length,
        ];
      });
      if (!rows.length) empty(b.el, 'Nenhum projeto disponível.');
      else
        b.c.setOption(
          {
            grid: { left: 8, right: 36, top: 8, bottom: 8, containLabel: true },
            tooltip: {
              trigger: 'axis',
              axisPointer: { type: 'shadow' },
              formatter:function(items){if(!items?.length)return 'Sem medição';var row=rows[items[0].dataIndex];return esc(row[0])+'<br>'+row[2]+' de '+row[3]+' com medição<br>'+(row[1]===null?'Sem medição':(row[2]<row[3]?'Média parcial informada: ':'Média informada: ')+row[1]+'%')},
            },
            xAxis: {
              type: 'value',
              max: 100,
              axisLabel: { formatter: '{value}%', color: '#66737c' },
              splitLine: { lineStyle: { color: '#e5e9ec' } },
            },
            yAxis: {
              type: 'category',
              inverse: true,
              data: rows.map(function (r) {
                return r[0]+' ('+r[2]+'/'+r[3]+' com medição)';
              }),
              axisLabel: { color: '#202a30', width: 130, overflow: 'truncate' },
              axisLine: { show: false },
              axisTick: { show: false },
            },
            series: [
              {
                type: 'bar',
                data: rows.map(function (r) {
                  return r[1];
                }),
                barWidth: 16,
                showBackground: true,
                backgroundStyle: { color: '#f4f5f5', borderRadius: 8 },
                itemStyle: { color: '#f37021', borderRadius: 8 },
                label: {
                  show: true,
                  position: 'right',
                  formatter: '{c}%',
                  color: '#002f47',
                  fontWeight: 700,
                },
              },
            ],
          },
          true
        );
    }

    var c = chartOn('dashAgency');
    if (c) {
      var g = {};
      all.forEach(function (i) {
        if (i.budget && !i.cancelled) {
          var k = i.agency || 'Não informado';
          g[k] = (g[k] || 0) + i.budget;
        }
      });
      var list = Object.keys(g)
        .map(function (k) {
          return [k, g[k]];
        })
        .sort(function (x, y) {
          return y[1] - x[1];
        })
        .slice(0, 8);
      if (!list.length)
        empty(c.el, 'Preencha o valor das obras para ver o investimento por órgão.');
      else
        c.c.setOption(
          {
            grid: { left: 8, right: 24, top: 8, bottom: 8, containLabel: true },
            tooltip: {
              trigger: 'axis',
              axisPointer: { type: 'shadow' },
              valueFormatter: function (v) {
                return money(v);
              },
            },
            xAxis: {
              type: 'value',
              axisLabel: {
                formatter: function (v) {
                  return v >= 1e6 ? v / 1e6 + ' mi' : v >= 1e3 ? v / 1e3 + ' mil' : v;
                },
                color: '#66737c',
              },
              splitLine: { lineStyle: { color: '#e5e9ec' } },
            },
            yAxis: {
              type: 'category',
              inverse: true,
              data: list.map(function (r) {
                return r[0];
              }),
              axisLabel: { color: '#202a30', width: 130, overflow: 'truncate' },
              axisLine: { show: false },
              axisTick: { show: false },
            },
            series: [
              {
                type: 'bar',
                data: list.map(function (r) {
                  return r[1];
                }),
                barWidth: 16,
                itemStyle: { color: '#002f47', borderRadius: 8 },
              },
            ],
          },
          true
        );
    }
  }
  window.addEventListener('resize', function () {
    live.forEach(function (c) {
      try {
        if (!c.isDisposed()) c.resize();
      } catch (e) {}
    });
  });

  /* lista aberta ao clicar num indicador */
  window.dashOpen = function (kind) {
    var projects = (typeof visible==='function'?visible():db.projects||[]);
    var all = rowsOf(projects).map(info);
    var f = {
      attention:[function(i){return i.idle},'Obras sem alteração há mais de '+IDLE_DAYS+' dias'],
      all: [
        function () {
          return true;
        },
        'Todas as obras',
      ],
      running: [
        function (i) {
          return i.running;
        },
        'Obras em andamento',
      ],
      done: [
        function (i) {
          return i.finished;
        },
        'Obras concluídas',
      ],
      stopped: [
        function (i) {
          return i.paralyzed;
        },
        'Obras paralisadas',
      ],
      late: [
        function (i) {
          return i.late;
        },
        'Obras atrasadas',
      ],
      owner: [
        function (i) {
          return i.noOwner;
        },
        'Obras sem responsável',
      ],
    }[kind];
    if (!f) return;
    var list = all.filter(f[0]);
    if(kind==='attention')list.sort(function(a,b){return b.idleDays-a.idleDays});
    var body = list.length
      ? '<div class="kpi-detail-list">' +
        list
          .slice(0, 150)
          .map(function (i) {
            return (
              '<button class="kpi-detail-row" type="button" onclick="closeModal();editRecord(\'' +
              esc(i.x.p.id) +
              "','" +
              esc(i.x.r.id) +
              '\')">' +
              '<span class="kpi-detail-icon">' +
              icon('folder') +
              '</span><span class="kpi-detail-main"><b>' +
              esc(i.title) +
              '</b><small>' +
              esc(i.x.p.name || '') +
              ' · ' +
              esc(i.status) +
              (kind==='attention'?' · '+esc(idleText(i.idleDays))+' (desde '+esc(dateTime(i.lastEdit))+')':'') +
              '</small></span><span class="kpi-detail-value">' +
              (i.progress !== null ? i.progress + '% ' : '') +
              '</span>' +
              icon('arrow') +
              '</button>'
            );
          })
          .join('') +
        (list.length > 150
          ? '<p class="kpi-empty">Mostrando 150 de ' +
            list.length +
            '. Use a busca em Projetos para ver o restante.</p>'
          : '') +
        '</div>'
      : '<p class="kpi-empty">Nenhuma obra nesta situação.</p>';
    modal(f[1] + ' (' + list.length + ')', body, btn('Fechar', 'closeModal()', 'close'));
  };

  /* Os scripts anteriores já desenharam a página (com a Visão geral antiga) antes
     desta função existir. Redesenha uma vez para a primeira abertura já sair nova. */
  try {
    if (typeof render === 'function' && typeof tab !== 'undefined' && tab === 'dashboard') render();
  } catch (e) {
    console.error(e);
  }
})();
