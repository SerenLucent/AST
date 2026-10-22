export const PET_IDS=['mochi','kuki'];
export const DECAY_MS=360000; // One point / six minutes = ten points / hour.
export function initialPets(now=Date.now()){return Object.fromEntries(PET_IDS.map(id=>[id,{hunger:75,updatedAt:now}]))}
export function hunger(pet,now=Date.now()){return Math.max(0,Math.min(100,pet.hunger)-Math.max(0,Math.floor((now-pet.updatedAt)/DECAY_MS)))}
export function fedPet(pet,now=Date.now()){const elapsed=Math.max(0,now-pet.updatedAt);return {hunger:Math.min(100,hunger(pet,now)+20),updatedAt:now-elapsed%DECAY_MS}}

// A durable, account-scoped outbox. UI never awaits its network requests.
export class PetCare {
 constructor({storage,shared=false,request,credit=()=>{},receive=()=>{},change=()=>{},now=()=>Date.now(),createId=()=>crypto.randomUUID(),localKey='ast-home-local-pets-v1',canSend=()=>true}){
  Object.assign(this,{storage,shared,request,credit,receive,change,now,createId,localKey,canSend});this.pets=initialPets(now());this.jobs=[];this.sequence=0;this.account=null;this.enabled=!shared;this.sending=false;this.error='';this.clockOffset=0;this.timer=null;
  if(!shared){try{this.pets=JSON.parse(storage.getItem(localKey))||this.pets}catch{}}
 }
 get key(){return 'ast-home-pet-outbox-v1:'+this.account}
 get bonus(){return this.shared?this.jobs.length:0}
 get time(){return this.now()+this.clockOffset}
 get view(){const pets=structuredClone(this.pets);for(const job of this.jobs)pets[job.petId]=fedPet(pets[job.petId],job.createdAt);return Object.fromEntries(PET_IDS.map(id=>[id,hunger(pets[id],this.time)]))}
 persist(){this.storage.setItem(this.key,JSON.stringify({account:this.account,sequence:this.sequence,jobs:this.jobs}))}
 accept(r,{feeding=false,preserveView=false}={}){
  if(!this.shared)return;
  if(!/^[a-f0-9]{64}$/.test(r.accountKey||''))throw Error('현재 계정을 확인할 수 없습니다.');
  if(this.account&&this.account!==r.accountKey)throw Error('계정이 변경되었습니다. 다시 입장해 주세요.');
  const first=!this.account;this.account=r.accountKey;this.enabled=r.home?.features?.pets===1;
  if(first){feeding=false;preserveView=false}
  if(!this.enabled){this.change();return}
  if(Number.isSafeInteger(r.home.revision)&&Number.isSafeInteger(this.revision)&&r.home.revision<this.revision)return;
  this.revision=r.home.revision;
  const ack=r.petCare?.sequence;if(!Number.isSafeInteger(ack)||ack<0||!r.pets||PET_IDS.some(id=>!Number.isFinite(r.pets[id]?.hunger)||!Number.isFinite(r.pets[id]?.updatedAt)))throw Error('돌보기 응답을 확인해 주세요.');
  if(first){try{const saved=JSON.parse(this.storage.getItem(this.key));if(saved?.account===this.account&&Array.isArray(saved.jobs))this.jobs=saved.jobs.filter(j=>PET_IDS.includes(j.petId)&&Number.isSafeInteger(j.sequence)&&j.sequence>ack&&typeof j.requestId==='string'&&Number.isFinite(j.createdAt))}catch{}}
  // Ignore an older response that arrives after a later purchase/sync.
  if(ack<this.sequence&&this.lastAck!==undefined&&ack<this.lastAck)return;
  const acknowledged=this.jobs.filter(j=>j.sequence<=ack);
  this.lastAck=ack;
  if(feeding&&r.status!=='full'){
   if(r.petCare.pets)this.pets=r.petCare.pets;
   else for(const job of acknowledged)this.pets[job.petId]=fedPet(this.pets[job.petId],job.createdAt);
  }else if(preserveView){for(const job of acknowledged)this.pets[job.petId]=fedPet(this.pets[job.petId],job.createdAt)}
  else this.pets=r.pets;
  if(Number.isFinite(r.serverNow))this.clockOffset=r.serverNow-this.now();
  this.jobs=this.jobs.filter(j=>j.sequence>ack);this.sequence=Math.max(ack,...this.jobs.map(j=>j.sequence));this.persist();this.error='';this.change();
 }
 feed(petId){
  if(!this.enabled||!PET_IDS.includes(petId)||this.view[petId]>80)return false;
  if(!this.shared){const pets={...this.pets,[petId]:fedPet(this.pets[petId],this.time)};this.storage.setItem(this.localKey,JSON.stringify(pets));this.pets=pets;this.credit(1);this.change();return true}
  const job={petId,sequence:this.sequence+1,requestId:this.createId(),createdAt:this.time};
  const old=this.jobs;this.jobs=[...old,job];this.sequence=job.sequence;
  try{this.persist()}catch(e){this.jobs=old;this.sequence--;this.error='저장 공간을 확인한 뒤 다시 시도해 주세요.';this.change();return false}
  this.error='';this.change();void this.flush();return true;
 }
 async flush(){
  if(this.sending||!this.enabled||!this.jobs.length)return;
  if(!this.canSend()){this.retry(250);return}
  this.sending=true;const job=this.jobs[0];
  try{
   const r=await this.request({action:'astHomeApply',operation:'feed',accountKey:this.account,requestId:job.requestId,petId:job.petId,feedSequence:job.sequence});
   if(r.accountKey!==this.account||!['applied','already_applied','full'].includes(r.status)||r.petCare?.sequence<job.sequence||!Number.isSafeInteger(r.balance)||r.balance<0||!Number.isSafeInteger(r.home?.revision))throw Error('먹이주기 전송을 확인하지 못했습니다.');
   // Update the authoritative balance before removing its optimistic +1.
   this.receive(r);this.accept(r,{feeding:true});
  }catch{this.error='연결되면 자동으로 전송합니다.';this.retry(5000)}
  finally{this.sending=false;this.change();if(!this.error&&this.jobs.length)this.retry(0)}
 }
 retry(ms){clearTimeout(this.timer);this.timer=setTimeout(()=>void this.flush(),ms);this.timer?.unref?.()}
 destroy(){clearTimeout(this.timer)}
}
