import assert from 'node:assert/strict';
import {registeredSprite,transformPoint,sourcePoint,spriteIndex,RECTANGULAR_SPRITES,tableSurfaceMatrix} from '../docs/games/ast-home/sprite-geometry.mjs';
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

for(const measured of [false,true]){const f={...frame,roof:{measured,left:{x:0,y:400},front:{x:150,y:500},right:{x:600,y:250}}},quad=[{x:0,y:0},{x:-120,y:60},{x:120,y:180},{x:240,y:120}],pose=registeredSprite('banquet-table',f,quad),m=tableSurfaceMatrix(f,pose,quad);
 for(const [u,v] of [[0,0],[1,0],[0,1],[1,1],[.4,.6]]){const p={x:quad[0].x+u*(quad[1].x-quad[0].x)+v*(quad[3].x-quad[0].x),y:quad[0].y-45+u*(quad[1].y-quad[0].y)+v*(quad[3].y-quad[0].y)},q=transformPoint(m,p),r=sourcePoint(m,q);assert.ok(Math.hypot(p.x-r.x,p.y-r.y)<1e-8,'visible tabletop cells and touch coordinates roundtrip')}
}
