import assert from 'node:assert/strict';
import {AREAS,STAIR,NAVIGATION,HOUSE_ITEMS,FLOOR_ONE_PLANES,project,unproject,canBuild,size,furniturePoint,spriteBox} from '../docs/games/ast-home/house-layout.mjs';
for(let x=0;x<24;x++)for(let y=0;y<30;y++){const q=unproject(project(x+.5,y+.5));assert.ok(Math.abs(q.x-x-.5)<1e-9&&Math.abs(q.y-y-.5)<1e-9)}
const a={uid:'piano-00000000001',area:'roomA',type:'piano',rotation:0,x:1,y:1};
assert.equal(canBuild(a,[]),true);assert.equal(canBuild({...a,area:'hall'},[]),false);
assert.equal(canBuild({...a,uid:'other-piano-0001'},[a]),false);assert.equal(canBuild({...a,area:'roomB'},[a]),true);
assert.equal(canBuild({...a,x:7},[]),false);assert.deepEqual(size({...a,rotation:1}),[3,2]);
assert.ok(AREAS.roomA.x<AREAS.hall.x,'practice rooms must be toward two oclock, behind arrival');
const table={uid:'table-00000000001',area:'dining',type:'banquet-table',rotation:0,x:4,y:5};
const food={uid:'fruit-00000000001',area:'dining',parent:table.uid,type:'fruit',rotation:0,x:0,y:0};
assert.equal(canBuild(table,[]),true);assert.equal(canBuild(food,[table]),true);assert.equal(canBuild({...food,parent:null},[table]),false);
assert.equal(canBuild({...food,parent:'missing'},[table]),false);assert.equal(canBuild({...food,y:7},[table]),false);
assert.equal(canBuild({...food,uid:'other-food-00001'},[table,food]),false);
for(let rotation=0;rotation<4;rotation++){const t={...table,rotation};assert.equal(canBuild(t,[food]),true);const p=furniturePoint(food,[t]);assert.ok(Number.isFinite(p.x)&&Number.isFinite(p.y))}
assert.equal(canBuild({...table,x:STAIR.x,y:STAIR.y},[]),false);
for(const d of HOUSE_ITEMS){const area=Object.entries(AREAS).find(([,a])=>d.places.includes(a.kind))?.[0];if(!area)continue;for(let rotation=0;rotation<4;rotation++)assert.equal(canBuild({type:d.id,area,x:1,y:1,rotation},[]),true,d.id+' rotation '+rotation)}
assert.equal(canBuild({...a,type:'tv-console'},[]),false);
assert.equal(canBuild({...a,type:'studio-speaker',area:'hall'},[]),false);
assert.deepEqual(NAVIGATION.filter(n=>typeof n.target==='number').map(n=>n.target),[2,1]);
for(const id of Object.keys(FLOOR_ONE_PLANES)){const a=AREAS[id];for(let x=0;x<=a.w;x++)for(let y=0;y<=a.h;y++){const p=project(a.x+x,a.y+y,1,id),q=unproject(p,1,id);assert.ok(Math.abs(q.x-a.x-x)<1e-9&&Math.abs(q.y-a.y-y)<1e-9)}const p=project(a.x,a.y,1,id),u=project(a.x+1,a.y,1,id),v=project(a.x,a.y+1,1,id);assert.ok(Math.abs(Math.hypot(u.x-p.x,u.y-p.y)-Math.hypot(v.x-p.x,v.y-p.y))<1e-9)}
assert.deepEqual(project(5,7,2,'dining'),{x:1060,y:590},'second-floor projection stays unchanged');
assert.equal(canBuild({...a,area:'roomA',x:1,y:5,type:'piano'},[]),false,'A room near wall is unavailable');
assert.equal(canBuild({uid:'stair-mask-check',type:'plant',area:'hall',x:7,y:25,rotation:0},[]),false,'no placement over visible staircase');
for(const type of ['coffee-table','elegant-sofa'])for(let rotation=0;rotation<4;rotation++){const item={uid:'contact-check',area:'hall',type,x:2,y:5,rotation},f={w:600,h:420,contactU:rotation%2?.3:.7,contactV:.98},box=spriteBox(item,f,[]),[w,h]=size(item),front=project(AREAS.hall.x+item.x+w,AREAS.hall.y+item.y+h,1,'hall');assert.ok(Math.abs(box.x+box.w*f.contactU-front.x)<1e-9,'nearest foot x matches floor corner');assert.ok(Math.abs(box.y+box.h*f.contactV-front.y)<1e-9,'nearest foot is grounded')}
console.log('House rules passed: regular square grid, corrected direction, room catalogs, collision, four rotations, stairs, table-only food, tabletop bounds and child transform');
