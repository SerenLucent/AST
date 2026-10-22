import {PetCare,PET_IDS} from './pet-care-model.mjs?v=20261022-pets1';
const names={mochi:'모모',kuki:'쿠키'};
const picture=(id,pose='front')=>`assets/pets/${id}-${pose}.webp`;
export function mountPetCare(options){
 const sheet=document.createElement('section');sheet.className='pet-care';sheet.setAttribute('aria-label','모모와 쿠키 돌보기');
 sheet.innerHTML=`<h2>모모와 쿠키 돌보기</h2><p>무료 먹이주기 · 포만감 +20 · 1 AST 받기</p><div class="pet-care-grid">${PET_IDS.map(id=>`<article class="pet-care-card"><img src="${picture(id)}" alt="${names[id]}"><div><strong>${names[id]}</strong><progress max="100" value="75" aria-label="${names[id]} 포만감"></progress><small data-hunger>포만감 75 / 100</small><button type="button" data-feed="${id}">먹이주기 · +1 AST</button></div></article>`).join('')}</div><span class="pet-care-note" role="status"></span>`;
 options.stage.insertAdjacentElement('afterend',sheet);
 const layer=document.createElement('div');layer.className='pet-wander-layer';layer.setAttribute('aria-hidden','true');options.stage.append(layer);
 const actors=PET_IDS.map(id=>{const el=document.createElement('div');el.className='pet-wander';el.innerHTML=`<img src="${picture(id)}" alt="" draggable="false"><span>냠냠! +1 AST</span>`;layer.append(el);return {id,el,from:null,to:null,start:0,end:0,space:null}});
 const care=new PetCare({...options,change:()=>{render();options.change?.()}});
 function render(){const view=care.view;PET_IDS.forEach((id,i)=>{const card=sheet.querySelectorAll('article')[i];card.querySelector('progress').value=view[id];card.querySelector('[data-hunger]').textContent=`포만감 ${view[id]} / 100`;const b=card.querySelector('button');b.disabled=!care.enabled||view[id]>80;b.textContent=view[id]>80?'아직 배불러요':'먹이주기 · +1 AST'});sheet.querySelector('.pet-care-note').textContent=!care.enabled?'돌보기 서버 연결이 필요합니다. 통합 Code.gs 업데이트 후 다시 연결해 주세요.':care.error|| (care.bonus?`${care.bonus}건 전송 중 · 화면은 계속 사용할 수 있어요`:'80 이하일 때 먹이를 줄 수 있어요 · 시간당 10 감소');}
 sheet.addEventListener('click',e=>{const button=e.target.closest('[data-feed]');if(!button)return;if(care.feed(button.dataset.feed)){const actor=actors.find(a=>a.id===button.dataset.feed);actor.el.classList.remove('fed');void actor.el.offsetWidth;actor.el.classList.add('fed')}});
 let frame=0,last=0,stopped=false;
 const reduced=matchMedia('(prefers-reduced-motion: reduce)').matches;
 function animate(time){if(stopped)return;frame=requestAnimationFrame(animate);if(time-last<33||document.hidden)return;last=time;const world=options.world();if(!world.ready){layer.hidden=true;return}layer.hidden=false;
  for(const actor of actors){
   if(actor.space!==world.space||time>=actor.end){const cells=world.cells(),key=p=>`${p.x},${p.y}`,map=new Map(cells.map(p=>[key(p),p]));if(!cells.length){actor.el.hidden=true;continue}actor.el.hidden=false;
    if(actor.space!==world.space||!actor.to||!map.has(key(actor.to))){actor.to=cells[Math.floor(Math.random()*cells.length)];actor.space=world.space}
    actor.from=actor.to;const neighbors=[[1,0],[-1,0],[0,1],[0,-1]].map(([x,y])=>map.get(`${actor.from.x+x},${actor.from.y+y}`)).filter(Boolean);actor.to=neighbors.length?neighbors[Math.floor(Math.random()*neighbors.length)]:actor.from;actor.start=time;actor.end=time+(reduced?3500:1400+Math.random()*1000);
    const a=world.project(actor.from),b=world.project(actor.to),dx=b.x-a.x,dy=b.y-a.y,pose=Math.abs(dx)>Math.abs(dy)*1.2?'side':dy<0?'back':'front',im=actor.el.querySelector('img');im.src=picture(actor.id,pose);im.dataset.flip=pose==='side'&&dx<0?'-1':'1';
   }
   const t=Math.min(1,(time-actor.start)/(actor.end-actor.start)),a=world.project(actor.from),b=world.project(actor.to),r=options.canvas.getBoundingClientRect(),host=options.stage.getBoundingClientRect(),scale=r.width/world.width;
   const x=world.camera.x+((1-t)*a.x+t*b.x)*world.camera.scale,y=world.camera.y+((1-t)*a.y+t*b.y)*world.camera.scale;
   actor.el.style.left=`${r.left-host.left+x*scale}px`;actor.el.style.top=`${r.top-host.top+y*scale}px`;actor.el.style.width=`${170*world.camera.scale*scale}px`;
  }
 }
 const tick=setInterval(()=>{render();void care.flush()},15000);const online=()=>void care.flush();window.addEventListener('online',online);frame=requestAnimationFrame(animate);render();
 const original=care.accept.bind(care);care.accept=(r,options)=>{original(r,options);void care.flush()};
 care.destroy=()=>{stopped=true;cancelAnimationFrame(frame);clearInterval(tick);clearTimeout(care.timer);window.removeEventListener('online',online);sheet.remove();layer.remove()};
 return care;
}
