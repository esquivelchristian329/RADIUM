/* RADIUM V34 - DepEd Draw Lots
   Supabase is authoritative. Draw numbers/seeds are stored at category-entry
   level so the same athlete can have different numbers in different events. */
(function(){
  'use strict';
  const $=id=>document.getElementById(id);
  const esc=s=>String(s??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
  const state=()=>window.__RADIUM_GET_DATA?window.__RADIUM_GET_DATA():null;
  const isAdminOrManager=()=>!!(window.RADIUM_AUTH?.isAdmin?.()||window.RADIUM_AUTH?.isManager?.());
  const isDepEdTournament=()=>{const d=state();if(!d)return false;const program=String(d.setup?.competitionProgram||'').toUpperCase();if(program==='DEPED_PEKAF'||program==='DEPED')return true;return (d.categories||[]).some(c=>String(c?.preset||'').toUpperCase().startsWith('DEPED-'));};
  const isDepEd=c=>isDepEdTournament()&&!!c;
  function refreshVisibility(){
    const visible=isDepEdTournament()&&isAdminOrManager();
    document.querySelectorAll('.nav-item[data-page="drawLotsPage"]').forEach(b=>{b.style.display=visible?'':'none';b.setAttribute('aria-hidden',visible?'false':'true');});
    const page=$('drawLotsPage');if(page&&!visible&&page.classList.contains('active')){page.classList.remove('active');document.getElementById('dashboardPage')?.classList.add('active');}
    const groups=[...document.querySelectorAll('.nav-group')];groups.forEach(g=>{const items=[...g.querySelectorAll('.nav-item')];if(items.length){const any=items.some(x=>getComputedStyle(x).display!=='none');g.style.display=any?'':'none';}});
  }
  const isAnyo=c=>c?.event==='Arnis Anyo';
  const isCombative=c=>c?.event!=='Arnis Anyo' && c?.event!=='Livestick';
  const categoryPlayers=(c)=>{
    const d=state(); if(!d||!c)return [];
    return (d.players||[]).filter(p=>typeof window.eligible==='function'?window.eligible(p,c):true);
  };
  function ensureIndividualEntries(c){
    const d=state(); if(!d||!c||c.anyoType!=='Individual')return;
    d.anyoEntries=Array.isArray(d.anyoEntries)?d.anyoEntries:[];
    for(const p of categoryPlayers(c)){
      if(!p.events?.anyoIndividual)continue;
      const exists=d.anyoEntries.some(e=>String(e.categoryId)===String(c.id)&&e.type==='Individual'&&Array.isArray(e.memberIds)&&String(e.memberIds[0])===String(p.id)&&e.status!=='deleted');
      if(!exists)d.anyoEntries.push({id:`tmp_${Date.now().toString(36)}_${Math.random().toString(36).slice(2)}`,number:p.number||('IND-'+String(d.anyoEntries.filter(e=>String(e.categoryId)===String(c.id)).length+1).padStart(3,'0')),type:'Individual',categoryId:c.id,style:c.anyoStyle||'Traditional',weapon:c.anyoWeapon,memberIds:[p.id],status:'active'});
    }
  }
  function competitors(c){
    const d=state(); if(!d||!c)return [];
    if(isAnyo(c)){
      if((c.anyoType||'Individual')==='Individual'){
        ensureIndividualEntries(c);
        return categoryPlayers(c).filter(p=>p.events?.anyoIndividual===true).map(p=>({kind:'player',id:p.id,name:p.name,teamId:p.teamId||'',player:p}));
      }
      return (d.anyoEntries||[]).filter(e=>String(e.categoryId)===String(c.id)&&e.type===(c.anyoType||'Synchronized')&&e.status!=='deleted').map(e=>({kind:'entry',id:e.id,name:e.number||e.id,teamId:(e.memberIds||[]).map(id=>(d.players||[]).find(p=>String(p.id)===String(id))).find(Boolean)?.teamId||'',entry:e}));
    }
    return categoryPlayers(c).map(p=>({kind:'player',id:p.id,name:p.name,teamId:p.teamId||'',player:p}));
  }
  function shuffle(a){const x=[...a];for(let i=x.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[x[i],x[j]]=[x[j],x[i]]}return x;}
  function teamName(id){const d=state();return d?.teams?.find(t=>String(t.id)===String(id))?.name||'—'}
  function selected(){const d=state();return d?.categories?.find(c=>String(c.id)===String($('drawLotsCategory')?.value))||null}
  function renderSelect(){
    const d=state(),s=$('drawLotsCategory');if(!s||!d)return;
    const cats=(d.categories||[]).filter(c=>isDepEd(c)&&(isAnyo(c)||isCombative(c)));
    s.innerHTML='<option value="">SELECT DEPED CATEGORY</option>'+cats.map(c=>`<option value="${esc(c.id)}">${esc(c.name)}</option>`).join('');
    if(d.activeCategory&&cats.some(c=>String(c.id)===String(d.activeCategory)))s.value=d.activeCategory;
    renderSelected();
  }
  function renderSelected(){
    const c=selected(),info=$('drawLotsInfo'),tb=$('drawLotsTable'),status=$('drawLotsStatus');
    if(!c){if(info)info.innerHTML='<strong>Select a category.</strong> Draws are independent per category.';if(tb)tb.innerHTML='<tr><td colspan="4" class="draw-lots-empty">No category selected.</td></tr>';if(status)status.textContent='NOT DRAWN';return;}
    const d=state(),list=competitors(c),any= isAnyo(c),type=any?(c.anyoType||'Individual'):'Combative';
    if(info)info.innerHTML=any?`<strong>DepEd Anyo:</strong> ${esc(type)} performance order for <b>${esc(c.name)}</b>. Each Anyo category has its own independent draw.`:`<strong>DepEd Combative:</strong> seed draw for <b>${esc(c.name)}</b>. The saved seeds are used by the bracket.`;
    const rows=list.map(x=>{let n=null;if(x.kind==='player')n=x.player?.categorySeeds?.[c.id]?.drawNumber;else n=x.entry?.drawOrder;return {...x,n:Number.isFinite(Number(n))?Number(n):null}}).sort((a,b)=>{if(a.n!=null&&b.n!=null)return a.n-b.n;if(a.n!=null)return -1;if(b.n!=null)return 1;return a.name.localeCompare(b.name)});
    const drawn=rows.length>0&&rows.every(x=>x.n!=null);
    if(status)status.textContent=drawn?'DRAW SAVED':'NOT DRAWN';
    if(tb)tb.innerHTML=rows.length?rows.map(x=>`<tr><td><b>${x.n==null?'—':x.n}</b></td><td><b>${esc(x.name)}</b></td><td>${esc(teamName(x.teamId))}</td><td>${x.kind==='entry'?'GROUP ENTRY':'PLAYER REGISTRATION'}</td></tr>`).join(''):'<tr><td colspan="4" class="draw-lots-empty">No eligible competitors/entries found.</td></tr>';
  }
  async function drawLots(){
    const c=selected(),d=state();if(!c||!d)return alert('Select a category first.');
    if(!isAdminOrManager())return alert('Only Admin or Tournament Manager can perform the official draw lots.');
    if(d.locked)return alert('Tournament is locked. Unlock it before changing draw lots.');
    const list=competitors(c);if(list.length<1)return alert('No eligible competitors or Anyo entries are available for this category.');
    const already=list.every(x=>x.kind==='player'?(Number.isFinite(Number(x.player?.categorySeeds?.[c.id]?.drawNumber))):(Number.isFinite(Number(x.entry?.drawOrder))));
    if(already&&!confirm('This category already has a saved draw. Redraw and replace the current order?'))return;
    const order=shuffle(list);
    const now=new Date().toISOString();
    if(isAnyo(c)){
      if((c.anyoType||'Individual')==='Individual'){
        for(let i=0;i<order.length;i++){const p=order[i].player;p.categorySeeds=p.categorySeeds||{};p.categorySeeds[c.id]={...(p.categorySeeds[c.id]||{}),drawNumber:i+1,drawType:'DEPED_LOTS',drawnAt:now};const e=(d.anyoEntries||[]).find(x=>String(x.categoryId)===String(c.id)&&x.type==='Individual'&&x.memberIds?.[0]===p.id);if(e){e.drawOrder=i+1;e.drawType='DEPED_LOTS';e.drawnAt=now;}}
      }else{
        for(let i=0;i<order.length;i++){const e=order[i].entry;e.drawOrder=i+1;e.drawType='DEPED_LOTS';e.drawnAt=now;}
      }
    }else{
      c.draw='seed';
      for(let i=0;i<order.length;i++){const p=order[i].player;p.categorySeeds=p.categorySeeds||{};p.categorySeeds[c.id]={...(p.categorySeeds[c.id]||{}),seed:i+1,drawNumber:i+1,drawType:'DEPED_LOTS',drawnAt:now};}
    }
    d.activeCategory=c.id;
    try{window.__RADIUM_SET_DATA?.(d);window.RADIUM_CLOUD?.scheduleSync?.();const ok=await window.RADIUM_CLOUD?.flush?.();if(ok===false)throw new Error('Supabase did not confirm the draw save.');renderSelect();renderSelected();if(window.renderAll)window.renderAll();alert('Draw lots saved to Supabase for this category.');}
    catch(e){console.error(e);alert('Draw lots was not confirmed by Supabase. No official draw should be considered saved. '+(e?.message||e));}
  }
  window.renderDrawLots=renderSelect;window.RADIUM_DRAW_LOTS={isDepEdTournament,refreshVisibility};
  function bind(){
    $('drawLotsCategory')?.addEventListener('change',()=>{const d=state();if(d)d.activeCategory=$('drawLotsCategory').value||null;renderSelected();});
    $('runDrawLotsBtn')?.addEventListener('click',drawLots);
    $('redrawLotsBtn')?.addEventListener('click',drawLots);
    $('refreshDrawLotsBtn')?.addEventListener('click',renderSelect);
    document.querySelectorAll('.nav-item[data-page="drawLotsPage"]').forEach(b=>b.addEventListener('click',()=>setTimeout(renderSelect,0)));
    refreshVisibility();renderSelect();
  }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',bind,{once:true});else bind();
})();
