// Sprite registration is measured in source pixels, independently of image
// padding. Structural rails follow the floor; the entire object stays intact.
export const SPRITE_ORDERS={
 'tv-console':[1,0,2,3],
 'wardrobe':[0,1,3,2],
 'banquet-table':[1,0,3,2]
};
export const RECTANGULAR_SPRITES=new Set(['wardrobe','table','sofa','elegant-sofa','coffee-table','bookshelf','piano','chair','studio-speaker','practice-desk','tv-console','lounge-chair','sideboard','banquet-table','dining-chair']);
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
 const upper=[];for(let x=l;x<=r;x++){let y=t;while(y<=b&&data[(y*width+x)*4+3]<180)y++;if(y<=b)upper.push({x:x+.5-l,y:b+1-y})}
 const roof=groundContacts(upper,r-l+1,b-t+1);
 const w=r-l+1,h=b-t+1,ground=groundContacts(points,w,h),lowest=points.reduce((a,b)=>b.y>a.y?b:a,{x:w/2,y:0});
 return {x:l,y:t,w,h,ground,roof,contactU:lowest.x/w,contactV:lowest.y/h};
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
  const g=frame.ground;
  // One transform for the entire object: parallel edges stay parallel and no
  // screen, tabletop, seat or cabinet is sliced through an arbitrary height.
  const roof=frame.roof,useRoof=roof?.measured&&['wardrobe','table','coffee-table','bookshelf','piano','studio-speaker','practice-desk','sideboard','banquet-table'].includes(type);
  const ml=useRoof?-(roof.right.y-roof.front.y)/(roof.right.x-roof.front.x):(g.front.y-g.left.y)/(g.front.x-g.left.x),mr=useRoof?-(roof.front.y-roof.left.y)/(roof.front.x-roof.left.x):(g.right.y-g.front.y)/(g.right.x-g.front.x);
  const kl=(front.y-left.y)/(front.x-left.x),kr=(right.y-front.y)/(right.x-front.x);
  const d=(kl-kr)/(ml-mr),b=kl-d*ml;
  const contacts=[g.left,g.front,g.right,{x:g.left.x+g.right.x-g.front.x,y:g.left.y+g.right.y-g.front.y}];
  const toCell=p=>{const x=p.x,y=b*p.x+d*p.y;return {x:(y-kr*x)/(kl-kr),y:(kl*x-y)/(kl-kr)}};
  const local=contacts.map(toCell),xs=local.map(p=>p.x),ys=local.map(p=>p.y),minX=Math.min(...xs),maxX=Math.max(...xs),minY=Math.min(...ys),maxY=Math.max(...ys);
  const a=Math.min((front.x-left.x)/(maxX-minX),(right.x-front.x)/(maxY-minY));
  const cx=(minX+maxX+minY+maxY)/2,cy=kl*(minX+maxX)/2+kr*(minY+maxY)/2;
  const matrix={a,b:a*b,c:0,d:a*d,e:(back.x+front.x)/2-a*cx,f:(back.y+front.y)/2-a*cy};
  parts=[{kind:'solid',x:0,w:frame.w,matrix}];
 }else{const width=Math.max(...quad.map(p=>p.x))-Math.min(...quad.map(p=>p.x)),food=['fruit','tea-set','bread'].includes(type),scale=width*(food?.78:.88)/frame.w,baseY=(back.y+front.y)/2+(front.y-back.y)*.28;parts=[{kind:'center',x:0,w:frame.w,matrix:{a:scale,b:0,c:0,d:scale,e:(back.x+front.x)/2-frame.w*(food?.5:(frame.contactU??.5))*scale,f:baseY-frame.h*(frame.contactV??1)*scale}}]}
 const points=parts.flatMap(part=>(part.clip||[{x:0,y:0},{x:frame.w,y:0},{x:frame.w,y:frame.h},{x:0,y:frame.h}]).map(p=>transformPoint(part.matrix,{x:p.x,y:Math.max(0,Math.min(frame.h,p.y))}))),xs=points.map(p=>p.x),ys=points.map(p=>p.y);
 return {matrix:parts[0].matrix,parts,quad,box:{x:Math.min(...xs),y:Math.min(...ys),w:Math.max(...xs)-Math.min(...xs),h:Math.max(...ys)-Math.min(...ys)}};
}
export function sourcePoint(matrix,p){const det=matrix.a*matrix.d-matrix.b*matrix.c;return {x:(matrix.d*(p.x-matrix.e)-matrix.c*(p.y-matrix.f))/det,y:(matrix.a*(p.y-matrix.f)-matrix.b*(p.x-matrix.e))/det}}
export function pointInClip(p,clip){if(!clip)return true;let yes=false;for(let i=0,j=clip.length-1;i<clip.length;j=i++){const a=clip[i],b=clip[j];if((a.y>p.y)!==(b.y>p.y)&&p.x<(b.x-a.x)*(p.y-a.y)/(b.y-a.y)+a.x)yes=!yes}return yes}
export function drawRegisteredSprite(ctx,image,frame,pose,alpha=1){for(const part of pose.parts){const m=part.matrix;ctx.save();ctx.globalAlpha=alpha;ctx.transform(m.a,m.b,m.c,m.d,m.e,m.f);if(part.clip){ctx.beginPath();part.clip.forEach((p,i)=>i?ctx.lineTo(p.x,p.y):ctx.moveTo(p.x,p.y));ctx.closePath();ctx.clip()}ctx.drawImage(image,frame.x,frame.y,frame.w,frame.h,0,0,frame.w,frame.h);ctx.restore()}}
