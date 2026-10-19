import {scanAtlas,spriteIndex,registeredSprite,drawRegisteredSprite} from './sprite-geometry.mjs?v=20261019-whole3';
import {TEST_KEY,readTestState,mountTestTools} from './test-session.mjs';
import {request as astRequest} from './ast-bridge.js?v=20261012-bridge1';
import {SharedHomeSession} from './shared-session.mjs?v=20261012-bridge1';
import {COLS,ROWS,BUILD_ROWS,catalog,footprint,canPlace,point,cell,spriteLayout,migrateLayout} from './model.mjs?v=20261019-whole3';
const $=id=>document.getElementById(id),canvas=$('game'),ctx=canvas.getContext('2d');
const testMode=new URLSearchParams(location.search).get('mode')==='test';if(testMode)mountTestTools();
const shared=new URLSearchParams(location.search).get('mode')==='shared';let revision=0,busy=false,walletReady=false,walletLoaded=false;
const sharedSession=shared?new SharedHomeSession({request:astRequest,storage:localStorage}):null;
const key=testMode?TEST_KEY:'myhome-prototype-v1';let state={coins:5000,items:[]},selected=null,draft=null,ready=false,hitboxes=[];
try{const s=shared?null:JSON.parse(localStorage.getItem(key));if(s&&Number.isFinite(s.coins)&&s.coins>=0&&Array.isArray(s.items)){const items=[];for(const i of s.items){if(catalog.some(t=>t.id===i.type)&&[i.x,i.y,i.rotation].every(Number.isInteger)&&i.rotation>=0&&i.rotation<4&&typeof i.uid==='string'&&!items.some(j=>j.uid===i.uid))items.push(i)}state={coins:s.coins,items:migrateLayout(items)}}}catch{}
if(testMode)state=readTestState(localStorage);
if(shared)state={coins:0,items:[]};
const images={},frames={};const bg=new Image();
function polygon(x,y,w=1,h=1){const p=[point(x,y),point(x+w,y),point(x+w,y+h),point(x,y+h)];ctx.beginPath();p.forEach((v,i)=>i?ctx.lineTo(v.x,v.y):ctx.moveTo(v.x,v.y));ctx.closePath()}
function message(s){$('status').textContent=s}
function save(){if(shared)return;try{localStorage.setItem(key,JSON.stringify(state))}catch{message('이 브라우저에서는 저장할 수 없습니다. 현재 배치는 세션 동안 유지됩니다.')}}
let memberNames={};
function updateCatalog(){for(const button of $('catalog').querySelectorAll('.card')){const item=catalog.find(t=>t.id===button.dataset.type);const insufficient=(!shared||walletLoaded)&&state.coins<item.price;const blocked=!ready||busy||(shared&&!walletReady);button.disabled=insufficient||blocked;button.classList.toggle('insufficient',insufficient);button.title=blocked?'서버 연결을 확인해 주세요.':insufficient?'아스트가 부족합니다.':`${item.name} 구매`;}}
function ui(){$('shopButton').disabled=!ready||busy||(shared&&!walletReady);updateCatalog();const chosen=state.items.find(i=>i.uid===selected);$('furnitureDetails').textContent=chosen?(chosen.placedBy?(memberNames[chosen.placedBy]||chosen.placedBy)+' · '+(chosen.purchasedAt?new Intl.DateTimeFormat('ko-KR',{timeZone:'Asia/Seoul',year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',hour12:false}).format(new Date(chosen.purchasedAt))+' 구매':'구매 시간 기록 없음'):'테스트 배치'):''; const cost=draft?.purchase?catalog.find(t=>t.id===draft.type).price:0;$('confirmCost').textContent=cost.toLocaleString();$('confirm').setAttribute('aria-label',`확정, ${cost} 아스트`); $('wallet').textContent=shared&&!walletLoaded?(busy?'잔액 확인 중…':'잔액 조회 필요'):`${state.coins.toLocaleString()} 아스트${shared&&!walletReady?' · 확인 필요':''}`;$('retrySync').hidden=ready&&(!shared||walletReady);$('retrySync').disabled=busy;$('retrySync').textContent=ready?'다시 연결':'다시 불러오기';$('actions').hidden=!selected||!!draft;$('placement').hidden=!draft;$('confirm').disabled=!ready||busy||(shared&&!walletReady)||!draft||!canPlace(draft,state.items)||(draft.purchase&&state.coins<catalog.find(t=>t.id===draft.type).price); }
function sprite(item,alpha=1){const f=frames[item.type][spriteIndex(item.type,item.rotation)],im=images[item.type],[w,h]=footprint(item),quad=[point(item.x,item.y),point(item.x+w,item.y),point(item.x+w,item.y+h),point(item.x,item.y+h)],pose=registeredSprite(item.type,f,quad);drawRegisteredSprite(ctx,im,f,pose,alpha);return {uid:item.uid,...pose.box}}

function draw(){if(!ready)return;ctx.clearRect(0,0,1536,1024);ctx.save();ctx.translate(camera.x,camera.y);ctx.scale(camera.scale,camera.scale);ctx.drawImage(bg,0,0,1536,1024);if(draft){for(let x=0;x<COLS;x++)for(let y=0;y<BUILD_ROWS;y++){polygon(x,y);ctx.fillStyle='rgba(255,255,230,.12)';ctx.fill();ctx.strokeStyle='rgba(73,73,43,.35)';ctx.lineWidth=1;ctx.stroke()}const [w,h]=footprint(draft);polygon(draft.x,draft.y,w,h);ctx.fillStyle=canPlace(draft,state.items)?'#63b97b88':'#d7515188';ctx.fill();ctx.strokeStyle='#fff';ctx.lineWidth=2;ctx.stroke()}
hitboxes=[];const entries=state.items.filter(i=>!i.area&&(!draft||i.uid!==draft.uid)).map(i=>({item:i,draft:false}));if(draft)entries.push({item:draft,draft:true});entries.sort((u,v)=>{const [w,h]=footprint(u.item),[vw,vh]=footprint(v.item);return point(u.item.x+w/2,u.item.y+h/2).y-point(v.item.x+vw/2,v.item.y+vh/2).y});for(const e of entries){if(e.item.uid===selected&&!draft){const [w,h]=footprint(e.item);polygon(e.item.x,e.item.y,w,h);ctx.strokeStyle='#fff8bd';ctx.lineWidth=3;ctx.stroke()}const box=sprite(e.item,e.draft?.68:1);if(!e.draft)hitboxes.push(box);}ctx.restore();ui();updateEnter()}
function begin(item,purchase=false){if(!item||!ready||busy||(shared&&!walletReady))return;draft={...item,purchase};selected=null;message('가구를 드래그하거나 바닥 셀을 눌러 이동한 뒤 O로 확정하세요.');draw()}
const camera={scale:1,x:0,y:0};
function clampCamera(){camera.x=Math.max(1536*(1-camera.scale),Math.min(0,camera.x));camera.y=Math.max(1024*(1-camera.scale),Math.min(0,camera.y));}
function zoom(delta){if(gesture)return;const old=camera.scale,next=Math.max(1,Math.min(3,Math.round((old+delta)*100)/100));camera.x=768-(768-camera.x)*next/old;camera.y=512-(512-camera.y)*next/old;camera.scale=next;clampCamera();$('zoomReset').textContent=Math.round(next*100)+'%';$('zoomOut').disabled=next===1;$('zoomIn').disabled=next===3;draw();}
$('zoomOut').onclick=()=>zoom(-.25);$('zoomIn').onclick=()=>zoom(.25);$('zoomReset').onclick=()=>{if(gesture)return;camera.scale=1;camera.x=0;camera.y=0;zoom(0)};
let gesture=null;
function pointerPoint(e){const r=canvas.getBoundingClientRect();return {x:((e.clientX-r.left)*1536/r.width-camera.x)/camera.scale,y:((e.clientY-r.top)*1024/r.height-camera.y)/camera.scale}}
function contains(box,p){return p.x>=box.x&&p.x<=box.x+box.w&&p.y>=box.y&&p.y<=box.y+box.h}
function placementMessage(){message(canPlace(draft,state.items)?'놓을 위치를 정한 뒤 O 확정 · X 취소':'다른 가구와 겹치거나 배치 영역 밖입니다.')}
canvas.addEventListener('pointerdown',e=>{if(e.pointerType==='touch'&&!e.isPrimary){if(gesture)abortGesture({pointerId:gesture.id});return}if(!ready||busy||(shared&&!walletReady)||gesture||(e.pointerType==='mouse'&&e.button!==0))return;const p=pointerPoint(e),c=cell(p),hit=draft?null:[...hitboxes].reverse().find(h=>contains(h,p));const grabbed=draft&&contains(spriteLayout(draft,frames[draft.type][draft.rotation]),p);gesture={id:e.pointerId,clientX:e.clientX,clientY:e.clientY,start:c,hit:hit?.uid,before:draft?{...draft}:null,item:draft?{...draft}:hit?{...state.items.find(i=>i.uid===hit.uid)}:null,relative:!!grabbed||!!hit,dragging:false,pan:!draft,panX:camera.x,panY:camera.y};canvas.setPointerCapture(e.pointerId);e.preventDefault()});
canvas.addEventListener('pointermove',e=>{const g=gesture;if(!g||g.id!==e.pointerId)return;if(!g.dragging&&Math.hypot(e.clientX-g.clientX,e.clientY-g.clientY)<6)return;if(g.pan){g.dragging=true;const r=canvas.getBoundingClientRect();camera.x=g.panX+(e.clientX-g.clientX)*1536/r.width;camera.y=g.panY+(e.clientY-g.clientY)*1024/r.height;clampCamera();draw();e.preventDefault();return}if(!g.dragging){if(!draft)return;g.dragging=true;canvas.classList.add('dragging')}const c=cell(pointerPoint(e));if(g.relative){draft.x=g.item.x+c.x-g.start.x;draft.y=g.item.y+c.y-g.start.y}else{draft.x=c.x;draft.y=c.y}placementMessage();draw();e.preventDefault()});
canvas.addEventListener('pointerup',e=>{const g=gesture;if(!g||g.id!==e.pointerId)return;gesture=null;canvas.classList.remove('dragging');if(!g.dragging){const c=cell(pointerPoint(e));if(draft){if(!g.relative&&c.x>=0&&c.y>=0&&c.x<COLS&&c.y<ROWS){draft.x=c.x;draft.y=c.y}placementMessage()}else{selected=g.hit||null;message(selected?'이동을 누른 뒤 가구를 드래그하세요.':'아이템 구매 버튼으로 가구를 골라보세요.')}}draw();if(canvas.hasPointerCapture(e.pointerId))canvas.releasePointerCapture(e.pointerId)});
function abortGesture(e){const g=gesture;if(!g||g.id!==e.pointerId)return;gesture=null;canvas.classList.remove('dragging');if(g.pan){camera.x=g.panX;camera.y=g.panY;draw();return}if(g.dragging){draft=g.before;selected=g.before?null:g.hit;message('드래그가 중단되어 이전 위치로 돌아왔습니다.');draw()}}
canvas.addEventListener('pointercancel',abortGesture);canvas.addEventListener('lostpointercapture',abortGesture);
$('shopButton').onclick=async()=>{if(draft){message('현재 배치를 확정하거나 취소한 뒤 구매하세요.');return}if(!ready){message('가구 이미지를 준비하는 중입니다.');return}if(!$('shop').open)$('shop').showModal();if(busy){$('shopNotice').textContent='아스트 잔액 확인 중…';return}if(shared){$('shopNotice').textContent='아스트 잔액 확인 중…';walletReady=false;updateCatalog();try{await syncShared();$('shopNotice').textContent='가구를 고른 뒤 바닥 셀에 배치하세요. 확정할 때 아스트가 사용됩니다.'}catch(e){$('shopNotice').textContent=e.message+' 목록을 닫고 다시 눌러 재시도하세요.';updateCatalog();return}}updateCatalog()};$('closeShop').onclick=()=>$('shop').close();
$('move').onclick=()=>begin(state.items.find(i=>i.uid===selected));$('rotateSelected').onclick=()=>{const i=state.items.find(i=>i.uid===selected);begin({...i,rotation:(i.rotation+1)%4})};$('rotateDraft').onclick=()=>{if(busy)return;draft.rotation=(draft.rotation+1)%4;draw()};
$('cancel').onclick=()=>{if(busy||!draft)return;const old=draft;draft=null;selected=old.purchase?null:old.uid;message('취소했습니다. 아스트는 사용되지 않았습니다.');draw()};$('confirm').onclick=async()=>{if(!ready||busy||(shared&&!walletReady)||!draft||!canPlace(draft,state.items))return;const t=catalog.find(t=>t.id===draft.type);if(draft.purchase&&state.coins<t.price)return;const {purchase,...item}=draft;if(shared){await commitShared(item,purchase);return}if(purchase){state.coins-=t.price;state.items.push(item)}else state.items=state.items.map(i=>i.uid===item.uid?item:i);draft=null;selected=null;message('배치했습니다. 가구를 누르면 이동·회전할 수 있습니다.');save();draw()};
function load(src){return new Promise((resolve,reject)=>{const i=new Image();i.onload=()=>resolve(i);i.onerror=()=>reject(new Error(src));i.src=src})}
function bounds(im){const c=document.createElement('canvas');c.width=im.width;c.height=im.height;const g=c.getContext('2d');g.drawImage(im,0,0);return scanAtlas(g.getImageData(0,0,c.width,c.height).data,c.width,c.height)}
async function start(){
  busy=true;ui();
  try{
    bg.src='assets/backgrounds/empty-living-grid-v4.png';await bg.decode();
    await Promise.all(catalog.map(async t=>{const im=await load(`assets/furniture/${t.id}-4dir.png`);images[t.id]=im;frames[t.id]=bounds(im)}));
    for(const t of catalog){
      const button=document.createElement('button');button.className='card';button.dataset.type=t.id;button.disabled=true;
      const preview=document.createElement('canvas');preview.width=180;preview.height=150;
      const g=preview.getContext('2d'),f=frames[t.id][0],scale=Math.min(160/f.w,135/f.h);
      g.drawImage(images[t.id],f.x,f.y,f.w,f.h,(180-f.w*scale)/2,(150-f.h*scale)/2,f.w*scale,f.h*scale);
      const name=document.createElement('strong');name.textContent=t.name;
      const price=document.createElement('span'),coin=document.createElement('img');coin.src='assets/ui/ast-coin.png';coin.className='ast-coin';coin.alt='';
      price.append(coin,document.createTextNode(`${t.price.toLocaleString()} 아스트`));button.append(preview,name,price);
      button.onclick=()=>{if(!ready||busy||(shared&&!walletReady))return;if(state.coins<t.price){message('아스트가 부족합니다.');$('shop').close();return}$('shop').close();begin({uid:crypto.randomUUID(),type:t.id,x:4,y:5,rotation:0},true)};
      $('catalog').append(button);
    }
    ready=true;
  }catch(e){message('게임 이미지를 불러오지 못했습니다. 인터넷 연결을 확인한 뒤 다시 불러오기를 눌러 주세요.');console.error(e);}
  finally{busy=false;ui();}
  if(!ready)return;
  draw();
  if(shared){try{await syncShared()}catch{/* syncShared keeps the actual error visible. */}}
  else message('아이템 구매 버튼으로 가구를 골라보세요.');
}
start();

function applyServer(result){if(!result.home||!Number.isInteger(result.home.revision)||!Array.isArray(result.home.items)||!Number.isSafeInteger(result.balance))throw new Error('서버 응답 형식 오류');memberNames=result.memberNames||memberNames;walletLoaded=true;revision=result.home.revision;state={coins:result.balance,items:result.home.items};draft=null;selected=null;}
async function syncShared(){
  if(busy)return;
  busy=true;walletReady=false;ui();message('서버에서 잔액과 거실을 확인하는 중…');
  try{
    await sharedSession.sync(result=>{applyServer(result);draw()});
    walletReady=true;message('공동 거실 · 아스트로 가구를 구매하고 배치하세요.');
  }catch(e){message('서버 연결 또는 구매 확인에 실패했습니다. '+e.message+' 다시 연결을 눌러 주세요.');throw e;}
  finally{busy=false;ui();draw();}
}
async function commitShared(item,purchase){
  if(busy||!walletReady)return;
  busy=true;walletReady=false;ui();message('서버에 배치를 저장하는 중…');
  try{
    const result=await sharedSession.commit(item,purchase,revision);
    applyServer(result);walletReady=true;
    message(result.status==='conflict'?'다른 팀원이 먼저 변경했습니다. 최신 배치로 새로고침했습니다.':result.status==='insufficient'?'아스트 잔액이 부족합니다.':'공동 거실에 저장했습니다.');
  }catch(e){message('구매·배치 결과를 확인하지 못했습니다. '+e.message+' 다시 연결을 눌러 결과를 확인하세요.');}
  finally{busy=false;ui();draw();}
}
$('retrySync').onclick=async()=>{if(busy)return;if(!ready){location.reload();return}try{await syncShared()}catch{/* Preserve the sync error and allow another retry. */}};

function updateEnter(){const b=$('enterMansion');if(!b)return;b.hidden=!!draft;b.disabled=busy;b.textContent='↗ ENTER · 1층';const p={x:camera.x+1090*camera.scale,y:camera.y+385*camera.scale};b.style.left=(p.x/1536*100)+'%';b.style.top=(p.y/1024*100)+'%';}
if($('enterMansion'))$('enterMansion').onclick=()=>{if(draft||busy)return;const url=new URL(location.href);url.searchParams.set('scene','mansion');location.href=url.href};
