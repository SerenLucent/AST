import assert from 'node:assert/strict';
import {registeredSprite,transformPoint,sourcePoint,spriteIndex,ROOF_HEIGHT,scanAtlas} from '../docs/games/ast-home/sprite-geometry.mjs';
assert.deepEqual([0,1,2,3].map(r=>spriteIndex('tv-console',r)),[1,0,2,3]);
assert.deepEqual([0,1,2,3].map(r=>spriteIndex('banquet-table',r)),[1,0,3,2]);
const frame={w:600,h:500,ground:{measured:true,left:{x:20,y:300},front:{x:420,y:490},right:{x:580,y:320}}};
for(const [tx,ty] of [[32.5,19.8],[30,18],[30,15],[40,20]])for(const type of Object.keys(ROOF_HEIGHT))for(let rotation=0;rotation<4;rotation++){
 const w=rotation%2?4:2,h=rotation%2?2:4,quad=[{x:500,y:500},{x:500-w*tx,y:500+w*ty},{x:500+(h-w)*tx,y:500+(w+h)*ty},{x:500+h*tx,y:500+h*ty}],pose=registeredSprite(type,frame,quad),g=frame.ground;
 for(const [source,target,m] of [[g.left,quad[1],pose.parts[1].matrix],[g.front,quad[2],pose.parts[1].matrix],[g.front,quad[2],pose.parts[2].matrix],[g.right,quad[3],pose.parts[2].matrix]]){const p=transformPoint(m,source);assert.ok(Math.hypot(p.x-target.x,p.y-target.y)<1e-8);const q=sourcePoint(m,p);assert.ok(Math.hypot(q.x-source.x,q.y-source.y)<1e-8)}
 for(const side of pose.parts.slice(1))assert.equal(side.matrix.c,0,'verticals remain vertical');
 const H=frame.h*ROOF_HEIGHT[type];for(const [p,side] of [[g.left,pose.parts[1]],[g.front,pose.parts[1]],[g.front,pose.parts[2]],[g.right,pose.parts[2]]]){const source={x:p.x,y:p.y-H},a=transformPoint(pose.parts[0].matrix,source),b=transformPoint(side.matrix,source);assert.ok(Math.hypot(a.x-b.x,a.y-b.y)<1e-8,'roof joins side without kink or gap')}
}
console.log('Sprite projection passed: TV/table orientation, all furniture profiles, four floor grids, four rotations, exact ground contacts, invertible picking, straight tops and upright sides');
