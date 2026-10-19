import assert from 'node:assert/strict';
import {AREAS,STAIR,NAVIGATION,HOUSE_ITEMS,project,unproject,canBuild,size,furniturePoint} from '../docs/games/ast-home/house-layout.mjs';
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
console.log('House rules passed: regular square grid, corrected direction, room catalogs, collision, four rotations, stairs, table-only food, tabletop bounds and child transform');
