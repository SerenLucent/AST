import assert from 'node:assert/strict';
import {registeredSprite,transformPoint,sourcePoint,spriteIndex,RECTANGULAR_SPRITES} from '../docs/games/ast-home/sprite-geometry.mjs';
assert.deepEqual([0,1,2,3].map(r=>spriteIndex('tv-console',r)),[1,0,2,3]);
assert.deepEqual([0,1,2,3].map(r=>spriteIndex('banquet-table',r)),[1,0,3,2]);
assert.deepEqual([0,1,2,3].map(r=>spriteIndex('wardrobe',r)),[0,1,3,2]);
const frame={w:600,h:500,ground:{measured:true,left:{x:20,y:300},front:{x:420,y:490},right:{x:580,y:320}}};
for(const [tx,ty] of [[32.5,19.8],[30,18],[30,15],[40,20]])for(const type of RECTANGULAR_SPRITES)for(let rotation=0;rotation<4;rotation++){
 const w=rotation%2?4:2,h=rotation%2?2:4,quad=[{x:500,y:500},{x:500-w*tx,y:500+w*ty},{x:500+(h-w)*tx,y:500+(w+h)*ty},{x:500+h*tx,y:500+h*ty}],pose=registeredSprite(type,frame,quad),g=frame.ground,m=pose.matrix;
 assert.equal(pose.parts.length,1,'the whole object uses one transform');assert.equal(m.c,0,'uprights remain vertical');assert.ok(m.a>0&&m.d>0);
 for(const [p,q] of [[g.left,g.front],[g.front,g.right]]){const a=transformPoint(m,p),b=transformPoint(m,q);assert.ok(Math.abs(Math.abs((b.y-a.y)/(b.x-a.x))-ty/tx)<1e-9,'entire parallel edge family follows floor axes')}
 for(const p of [g.left,g.front,g.right]){const q=transformPoint(m,p),r=sourcePoint(m,q);assert.ok(Math.hypot(r.x-p.x,r.y-p.y)<1e-8);const x=((q.y-500)/ty-(q.x-500)/tx)/2,y=((q.y-500)/ty+(q.x-500)/tx)/2;assert.ok(x>=-1e-8&&x<=w+1e-8&&y>=-1e-8&&y<=h+1e-8,'ground stays within reserved cells')}
 const a=transformPoint(m,{x:0,y:20}),b=transformPoint(m,{x:600,y:320}),mid=transformPoint(m,{x:300,y:170});assert.ok(Math.hypot(mid.x-(a.x+b.x)/2,mid.y-(a.y+b.y)/2)<1e-8,'long edges cannot kink at a slice');
}
console.log('Whole-frame projection passed: all rectangular profiles, four floor planes, four rotations, parallel edge families, no slicing, verticals, cell containment and inverse picking');
