import {PetWalker,cellKey} from './pet-walk.mjs?v=20261022-pets3';
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
 const walker=new PetWalker(PET_IDS,{reduced});
 function animate(time){if(stopped)return;frame=requestAnimationFrame(animate);if(time-last<33||document.hidden)return;last=time;const world=options.world();if(!world.ready){layer.hidden=true;return}layer.hidden=false;
  for(const pose of walker.update(time,world)){
   const actor=actors.find(a=>a.id===pose.id);actor.el.hidden=!pose.visible;if(!pose.visible)continue;
   const a=world.project(pose.from),b=world.project(pose.to),dx=b.x-a.x,dy=b.y-a.y,im=actor.el.querySelector('img');
   if(pose.moving){const facing=Math.abs(dx)>Math.abs(dy)*1.2?'side':dy<0?'back':'front';if(im.dataset.pose!==facing){im.src=picture(actor.id,facing);im.dataset.pose=facing}im.dataset.flip=facing==='side'&&dx<0?'-1':'1'}
   const r=options.canvas.getBoundingClientRect(),host=options.stage.getBoundingClientRect(),scale=r.width/world.width;
   const x=world.camera.x+pose.point.x*world.camera.scale,y=world.camera.y+pose.point.y*world.camera.scale;
   actor.el.dataset.from=cellKey(pose.from);actor.el.dataset.to=cellKey(pose.to);actor.el.dataset.duration=String(pose.duration);
   actor.el.style.left=`${r.left-host.left+x*scale}px`;actor.el.style.top=`${r.top-host.top+y*scale}px`;actor.el.style.width=`${170*world.camera.scale*scale}px`;actor.el.style.zIndex=String(Math.round(pose.point.y));
  }
 }
 const tick=setInterval(()=>{render();void care.flush()},15000);const online=()=>void care.flush();window.addEventListener('online',online);frame=requestAnimationFrame(animate);render();
 const original=care.accept.bind(care);care.accept=(r,options)=>{original(r,options);void care.flush()};
 care.destroy=()=>{stopped=true;cancelAnimationFrame(frame);clearInterval(tick);clearTimeout(care.timer);window.removeEventListener('online',online);sheet.remove();layer.remove()};
 return care;
}
