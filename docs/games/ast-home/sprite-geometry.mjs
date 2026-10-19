// Sprite registration is measured in source pixels, independently of image
// padding. The three ground contacts are mapped onto the logical floor quad.
export const SPRITE_ORDERS={
 'tv-console':[1,0,2,3],
 'banquet-table':[1,0,3,2]
};
export const RECTANGULAR_SPRITES=new Set(['wardrobe','table','sofa','elegant-sofa','coffee-table','bookshelf','piano','chair','studio-speaker','practice-desk','tv-console','lounge-chair','sideboard','banquet-table','dining-chair']);
export const ROOF_HEIGHT={wardrobe:.76,table:.50,sofa:.42,'elegant-sofa':.42,'coffee-table':.27,bookshelf:.72,piano:.70,chair:.40,'studio-speaker':.64,'practice-desk':.52,'tv-console':.25,'lounge-chair':.43,sideboard:.51,'banquet-table':.26,'dining-chair':.39};
export function spriteIndex(type,rotation){return (SPRITE_ORDERS[type]||[0,1,2,3])[rotation%4]}
const cross=(a,b,c)=>(b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x);
export function groundContacts(points,w,h){
 const hull=[];for(const p of points){while(hull.length>1&&cross(hull.at(-2),hull.at(-1),p)>=0)hull.pop();hull.push(p)}
 const edges=hull.slice(1).map((p,i)=>({a:hull[i],b:p,dx:p.x-hull[i].x,dy:p.y-hull[i].y}));
 const left=edges.filter(e=>e.dx>w*.08&&e.dy>e.dx*.12&&e.dy<e.dx*2&&Math.min(e.a.y,e.b.y)>h*.30).sort((a,b)=>b.dx-a.dx)[0];
 const right=edges.filter(e=>e.dx>w*.08&&e.dy<-e.dx*.12&&e.dy>-e.dx*2&&Math.min(e.a.y,e.b.y)>h*.30).sort((a,b)=>b.dx-a.dx)[0];
 if(left&&right){const ml=left.dy/left.dx,mr=right.dy/right.dx,bl=left.a.y-ml*left.a.x,br=right.a.y-mr*right.a.x,fx=(br-bl)/(ml-mr),fy=ml*fx+bl;if(fx>left.a.x&&fx<right.b.x&&fy<h*1.12)return {left:left.a,front:{x:fx,y:fy},right:right.b,measured:true}}
 const bottom=points.reduce((a,b)=>b.y>a.y?b:a,{x:w/2,y:h});return {left:{x:0,y:h*.7},front:bottom,right:{x:w,y:h*.7},measured:false};
}
export function scanAtlas(data,width,height){return [0,1,2,3].map(n=>{
 const sx=Math.floor(n%2*width/2),sy=Math.floor(Math.floor(n/2)*height/2),ex=Math.floor((n%2+1)*width/2),ey=Math.floor((Math.floor(n/2)+1)*height/2);let l=ex,r=sx,t=ey,b=sy,minY=sy,segment=0,started=false;
 // A neighboring sprite's clipped foot can leave a tiny island at the atlas
 // divider. Exclude that island from frame registration, not the main object.
 for(let y=sy;y<Math.min(ey,sy+64);y++){let row=0;for(let x=sx;x<ex;x++)if(data[(y*width+x)*4+3]>40)row++;if(row){if(!started&&y-sy>8)break;started=true;segment+=row}else if(started){if(segment<(ex-sx)*(ey-sy)*.005)minY=y+1;break}}
 for(let y=minY;y<ey;y++)for(let x=sx;x<ex;x++)if(data[(y*width+x)*4+3]>40){l=Math.min(l,x);r=Math.max(r,x);t=Math.min(t,y);b=Math.max(b,y)}
 if(l>r||t>b)throw Error('빈 가구 이미지 방향입니다.');
 const points=[];for(let x=l;x<=r;x++){let y=b;while(y>=t&&data[(y*width+x)*4+3]<180)y--;if(y>=t)points.push({x:x+.5-l,y:y+1-t})}
 const w=r-l+1,h=b-t+1,ground=groundContacts(points,w,h),lowest=points.reduce((a,b)=>b.y>a.y?b:a,{x:w/2,y:0});
 return {x:l,y:t,w,h,ground,contactU:lowest.x/w,contactV:lowest.y/h};
})}
export function affineFromTriangles(source,target){
 const [s0,s1,s2]=source,[t0,t1,t2]=target,ux=s1.x-s0.x,uy=s1.y-s0.y,vx=s2.x-s0.x,vy=s2.y-s0.y,det=ux*vy-uy*vx;if(Math.abs(det)<1e-6)throw Error('가구 바닥 기준점이 겹칩니다.');
 const tx=t1.x-t0.x,ty=t1.y-t0.y,rx=t2.x-t0.x,ry=t2.y-t0.y,a=(tx*vy-rx*uy)/det,c=(rx*ux-tx*vx)/det,b=(ty*vy-ry*uy)/det,d=(ry*ux-ty*vx)/det;
 return {a,b,c,d,e:t0.x-a*s0.x-c*s0.y,f:t0.y-b*s0.x-d*s0.y};
}
export function transformPoint(m,p){return {x:m.a*p.x+m.c*p.y+m.e,y:m.b*p.x+m.d*p.y+m.f}}
export function registeredSprite(type,frame,quad){
 const [back,left,front,right]=quad;let parts;
 if(RECTANGULAR_SPRITES.has(type)&&frame.ground?.measured){
  const g=frame.ground,al=(left.x-front.x)/(g.left.x-g.front.x),ar=(right.x-front.x)/(g.right.x-g.front.x),d=Math.sqrt(al*ar);
  const H=frame.h*(ROOF_HEIGHT[type]??.5),topL={x:g.left.x,y:g.left.y-H},topF={x:g.front.x,y:g.front.y-H},topR={x:g.right.x,y:g.right.y-H},roofLeft=x=>topF.y+(x-topF.x)*(topL.y-topF.y)/(topL.x-topF.x),roofRight=x=>topF.y+(x-topF.x)*(topR.y-topF.y)/(topR.x-topF.x);
  const side=(source,target,a,clip,kind)=>{const b=(target.y-front.y-d*(source.y-g.front.y))/(source.x-g.front.x);return {kind,x:0,w:frame.w,clip,matrix:{a,b,c:0,d,e:front.x-a*g.front.x,f:front.y-b*g.front.x-d*g.front.y}}};
  // Horizontal top and two upright faces share the same edge endpoints.
  // This avoids bending long table tops or leaning cabinet uprights.
  const top=affineFromTriangles([topL,topF,topR],[left,front,right].map(p=>({x:p.x,y:p.y-d*H})));
  parts=[{kind:'top',x:0,w:frame.w,matrix:top,clip:[{x:0,y:0},{x:frame.w,y:0},{x:frame.w,y:roofRight(frame.w)},topF,{x:0,y:roofLeft(0)}]},side(g.left,left,al,[{x:0,y:roofLeft(0)},topF,{x:topF.x,y:frame.h},{x:0,y:frame.h}],'left'),side(g.right,right,ar,[topF,{x:frame.w,y:roofRight(frame.w)},{x:frame.w,y:frame.h},{x:topF.x,y:frame.h}],'right')];
 }else{const width=Math.max(...quad.map(p=>p.x))-Math.min(...quad.map(p=>p.x)),food=['fruit','tea-set','bread'].includes(type),scale=width*(food?.78:.88)/frame.w,baseY=(back.y+front.y)/2+(front.y-back.y)*.28;parts=[{kind:'center',x:0,w:frame.w,matrix:{a:scale,b:0,c:0,d:scale,e:(back.x+front.x)/2-frame.w*(food?.5:(frame.contactU??.5))*scale,f:baseY-frame.h*(frame.contactV??1)*scale}}]}
 const points=parts.flatMap(part=>(part.clip||[{x:0,y:0},{x:frame.w,y:0},{x:frame.w,y:frame.h},{x:0,y:frame.h}]).map(p=>transformPoint(part.matrix,{x:p.x,y:Math.max(0,Math.min(frame.h,p.y))}))),xs=points.map(p=>p.x),ys=points.map(p=>p.y);
 return {matrix:parts[0].matrix,parts,quad,box:{x:Math.min(...xs),y:Math.min(...ys),w:Math.max(...xs)-Math.min(...xs),h:Math.max(...ys)-Math.min(...ys)}};
}
export function sourcePoint(matrix,p){const det=matrix.a*matrix.d-matrix.b*matrix.c;return {x:(matrix.d*(p.x-matrix.e)-matrix.c*(p.y-matrix.f))/det,y:(matrix.a*(p.y-matrix.f)-matrix.b*(p.x-matrix.e))/det}}
export function pointInClip(p,clip){if(!clip)return true;let yes=false;for(let i=0,j=clip.length-1;i<clip.length;j=i++){const a=clip[i],b=clip[j];if((a.y>p.y)!==(b.y>p.y)&&p.x<(b.x-a.x)*(p.y-a.y)/(b.y-a.y)+a.x)yes=!yes}return yes}
export function drawRegisteredSprite(ctx,image,frame,pose,alpha=1){for(const part of pose.parts){const m=part.matrix;ctx.save();ctx.globalAlpha=alpha;ctx.transform(m.a,m.b,m.c,m.d,m.e,m.f);if(part.clip){ctx.beginPath();part.clip.forEach((p,i)=>i?ctx.lineTo(p.x,p.y):ctx.moveTo(p.x,p.y));ctx.closePath();ctx.clip()}ctx.drawImage(image,frame.x,frame.y,frame.w,frame.h,0,0,frame.w,frame.h);ctx.restore()}}
