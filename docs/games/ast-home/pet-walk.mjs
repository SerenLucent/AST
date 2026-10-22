export const cellKey=p=>`${p.x},${p.y}`;
export const facingFor=(dx,dy)=>Math.abs(dx)>Math.abs(dy)*1.2?'side':dy<0?'back':'front';
export const stepDuration=(random=Math.random,reduced=false)=>reduced?1750:700+random()*500;
const same=(a,b)=>a&&b&&a.x===b.x&&a.y===b.y;
const overlap=(a,b)=>a.left<b.right&&b.left<a.right&&a.top<b.bottom&&b.top<a.bottom;

// Reserve the whole travel segment, not only the destination. The sprite's
// visible body and bounce clearance must also fit beside the other pet.
export function travelBounds(from,to,project){
 const a=project(from),b=project(to);
 return {left:Math.min(a.x,b.x)-89,right:Math.max(a.x,b.x)+89,top:Math.min(a.y,b.y)-196,bottom:Math.max(a.y,b.y)+4};
}
export class PetWalker {
 constructor(ids,{random=Math.random,reduced=false}={}){this.random=random;this.reduced=reduced;this.states=ids.map(id=>({id,cell:null,target:null,previous:null,start:0,end:0}));this.space=null;this.layout=null;this.edit=null;this.length=-1;this.map=new Map()}
 available(p){return p&&this.map.has(cellKey(p))}
 clearFor(actor,from,to,world){
  if(!this.available(from)||!this.available(to))return false;
  const body=travelBounds(from,to,world.project);
  return this.states.every(other=>other===actor||!other.cell||(
   ![other.cell,other.target].some(p=>same(p,from)||same(p,to))&&
   !overlap(body,travelBounds(other.cell,other.target||other.cell,world.project))));
 }
 reset(actor,world,time){
  const old=actor.cell;actor.cell=null;actor.target=null;actor.previous=null;
  const candidates=[...this.map.values()];
  if(old)candidates.sort((a,b)=>(Math.abs(a.x-old.x)+Math.abs(a.y-old.y))-(Math.abs(b.x-old.x)+Math.abs(b.y-old.y)));
  else {
   // Prefer roomy interior cells, rather than the extreme corner or stair gap.
   const points=candidates.map(world.project),cx=points.reduce((v,p)=>v+p.x,0)/(points.length||1),cy=points.reduce((v,p)=>v+p.y,0)/(points.length||1);
   const score=p=>{let clearance=0;for(let r=1;r<=5;r++){let open=true;for(let dx=-r;dx<=r;dx++)for(let dy=-r;dy<=r;dy++)if(!this.available({x:p.x+dx,y:p.y+dy}))open=false;if(!open)break;clearance=r;}const q=world.project(p);return clearance*10000-Math.hypot(q.x-cx,q.y-cy)};
   const scores=new Map(candidates.map(p=>[cellKey(p),score(p)]));candidates.sort((a,b)=>scores.get(cellKey(b))-scores.get(cellKey(a)));
   // In a tiny room start at an edge only if a central spawn leaves no room for the second body.
   if(!this.states.some(other=>other!==actor&&other.cell)&&this.states.length>1){const viable=candidates.filter(p=>candidates.some(q=>!overlap(travelBounds(p,p,world.project),travelBounds(q,q,world.project))));if(viable.length)candidates.splice(0,candidates.length,...viable);}
  }
  const next=candidates.find(p=>this.clearFor(actor,p,p,world));
  if(next){actor.cell=next;actor.target=next;actor.start=time;actor.end=time}
 }
 update(time,world){
  const changedSpace=this.space!==world.space;
  if(changedSpace){this.space=world.space;for(const actor of this.states){actor.cell=null;actor.target=null;actor.previous=null}}
  const changed=changedSpace||this.layout!==world.layout||this.length!==world.layout?.length||this.edit!==world.edit;
  if(changed){this.layout=world.layout;this.length=world.layout?.length;this.edit=world.edit;this.map=new Map(world.cells().map(p=>[cellKey(p),p]));}
  for(const actor of this.states){
   // Recheck immediately when furniture is placed or dragged into a route.
   if(changed&&(!this.available(actor.cell)||!this.available(actor.target))){
    if(this.available(actor.cell)){actor.target=actor.cell;actor.start=time;actor.end=time}
    else this.reset(actor,world,time);
   }
   if(!actor.cell)this.reset(actor,world,time);
   if(actor.cell&&time>=actor.end){if(!same(actor.cell,actor.target))actor.previous=actor.cell;actor.cell=actor.target;}
  }
  for(const actor of this.states){
   if(!actor.cell||time<actor.end)continue;
   let neighbors=[[1,0],[0,1],[-1,0],[0,-1],[1,1],[-1,-1],[1,-1],[-1,1]].filter(([x,y])=>!x||!y||(this.available({x:actor.cell.x+x,y:actor.cell.y})&&this.available({x:actor.cell.x,y:actor.cell.y+y}))).map(([x,y])=>this.map.get(`${actor.cell.x+x},${actor.cell.y+y}`)).filter(p=>p&&this.clearFor(actor,actor.cell,p,world));
   const forward=neighbors.filter(p=>!same(p,actor.previous));if(forward.length)neighbors=forward;
   actor.target=neighbors.length?neighbors[Math.floor(this.random()*neighbors.length)]:actor.cell;actor.start=time;actor.end=time+(neighbors.length?stepDuration(this.random,this.reduced):250);
  }
  return this.states.map(actor=>{if(!actor.cell)return {id:actor.id,visible:false};const t=Math.max(0,Math.min(1,(time-actor.start)/(actor.end-actor.start||1))),a=world.project(actor.cell),b=world.project(actor.target);return {id:actor.id,visible:true,from:actor.cell,to:actor.target,progress:t,duration:actor.end-actor.start,moving:!same(actor.cell,actor.target),point:{x:a.x+(b.x-a.x)*t,y:a.y+(b.y-a.y)*t}}});
 }
}
