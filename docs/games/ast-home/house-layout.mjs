import {registeredSprite} from './sprite-geometry.mjs?v=20261019-planes1';
// This logical square grid is the single source of truth for rendering and rules.
export const WORLD={width:2048,height:1536,cols:24,rows:30,origin:{x:1000,y:210},tileX:30,tileY:15};
export const AREAS={
 hall:{name:'1층 거실',floor:1,x:9,y:0,w:15,h:30,kind:'living'},
 roomA:{name:'A룸 · 연습실',floor:1,x:0,y:0,w:8,h:9,kind:'practice'},
 roomB:{name:'B룸 · 연습실',floor:1,x:0,y:10,w:8,h:9,kind:'practice'},
 roomC:{name:'C룸 · 연습실',floor:1,x:0,y:20,w:8,h:10,kind:'practice'},
 dining:{name:'2층 다이닝 홀',floor:2,x:0,y:0,w:24,h:30,kind:'dining'}
};
export const STAIR={x:20,y:23,w:4,h:7};
// Art anchors are fractions of the full canvas, independent of camera zoom.
export const NAVIGATION=[
 {id:'exit',floor:1,x:.195,y:.578,label:'↙ 테라스로 나가기',target:'exit'},
 {id:'roomA',floor:1,x:.405,y:.303,label:'↗ A룸',target:'roomA'},
 {id:'roomB',floor:1,x:.535,y:.405,label:'↗ B룸',target:'roomB'},
 {id:'roomC',floor:1,x:.685,y:.535,label:'↗ C룸',target:'roomC'},
 {id:'upstairs',floor:1,x:.633,y:.674,label:'↑ 2층 올라가기',target:2},
 {id:'downstairs',floor:2,x:.674,y:.674,label:'↓ 1층 내려가기',target:1}
];
// Each painted first-floor room has its own floor origin. Both tile axes
// have equal length: these are regular square cells in orthographic projection.
export const FLOOR_ONE_PLANES={
 hall:{x:644,y:413,tx:32.5,ty:19.8},
 roomA:{x:990,y:208,tx:30,ty:18},
 roomB:{x:1269,y:376,tx:30,ty:18},
 roomC:{x:1584,y:536,tx:30,ty:18}
};
export function project(x,y,floor=1,areaId=null){const p=floor===1&&FLOOR_ONE_PLANES[areaId],a=AREAS[areaId];if(p){x-=a.x;y-=a.y;return {x:p.x+(y-x)*p.tx,y:p.y+(x+y)*p.ty}}return {x:1000+(y-x)*30,y:(floor===1?210:410)+(x+y)*15}}
export function unproject(p,floor=1,areaId=null){const v=floor===1&&FLOOR_ONE_PLANES[areaId],a=AREAS[areaId];if(v){const sum=(p.y-v.y)/v.ty,difference=(p.x-v.x)/v.tx;return {x:a.x+(sum-difference)/2,y:a.y+(sum+difference)/2}}const dy=p.y-(floor===1?210:410);return {x:dy/30-(p.x-1000)/60,y:dy/30+(p.x-1000)/60}}
// Ground footprint of the approved staircase, measured on the painted floor.
export const HALL_STAIR_FOOTPRINT=[{x:1020,y:870},{x:1410,y:830},{x:1520,y:920},{x:1520,y:1210},{x:1340,y:1230},{x:1020,y:1040}];
// The cutaway partition hides the near edge of A room. Do not offer cells
// whose floor is covered by that wall in the painted background.
export const VISIBLE_BUILD_BOUNDS={roomA:{x:1,y:1,w:6,h:5}};
export function polygonsOverlap(a,b){for(const poly of [a,b])for(let i=0;i<poly.length;i++){const v=poly[i],w=poly[(i+1)%poly.length],axis={x:-(w.y-v.y),y:w.x-v.x},ap=a.map(p=>p.x*axis.x+p.y*axis.y),bp=b.map(p=>p.x*axis.x+p.y*axis.y);if(Math.max(...ap)<=Math.min(...bp)||Math.max(...bp)<=Math.min(...ap))return false}return true}
export const HOUSE_ITEMS=[
 {id:'elegant-sofa',name:'클래식 소파',price:180,w:2,h:4,places:['living'],asset:'elegant-sofa',category:'가구'},
 {id:'coffee-table',name:'낮은 커피 테이블',price:60,w:2,h:3,places:['living'],asset:'coffee-table',category:'가구'},
 {id:'plant',name:'실내 화분',price:40,w:1,h:1,places:['living','practice','dining'],asset:'plant',category:'장식'},
 {id:'bookshelf',name:'악보 책장',price:80,w:1,h:2,places:['living','practice'],asset:'bookshelf',category:'가구'},
 {id:'piano',name:'업라이트 피아노',price:250,w:2,h:3,places:['practice'],asset:'piano',category:'악기'},
 {id:'microphone',name:'마이크',price:70,w:1,h:1,places:['practice'],asset:'microphone',category:'연습 장비'},
 {id:'music-stand',name:'악보 거치대',price:40,w:1,h:1,places:['practice'],asset:'music-stand',category:'연습 장비'},
 {id:'chair',name:'연습 의자',price:30,w:1,h:1,places:['practice'],asset:'chair',category:'가구'},
 {id:'studio-speaker',name:'스튜디오 스피커',price:120,w:1,h:1,places:['practice'],asset:'studio-speaker',category:'연습 장비'},
 {id:'practice-desk',name:'연습용 탁자',price:90,w:2,h:3,places:['practice'],asset:'practice-desk',category:'가구'},
 {id:'guitar',name:'어쿠스틱 기타',price:110,w:1,h:1,places:['practice'],asset:'guitar',category:'악기'},
 {id:'drum-kit',name:'컴팩트 드럼 세트',price:280,w:3,h:3,places:['practice'],asset:'drum-kit',category:'악기'},
 {id:'tv-console',name:'LCD TV와 거실장',price:220,w:1,h:4,places:['living'],asset:'tv-console',category:'가구'},
 {id:'lounge-chair',name:'클래식 암체어',price:100,w:2,h:2,places:['living','dining'],asset:'lounge-chair',category:'가구'},
 {id:'floor-lamp',name:'브라스 장스탠드',price:65,w:1,h:1,places:['living','dining'],asset:'floor-lamp',category:'장식'},
 {id:'sideboard',name:'다이닝 수납장',price:140,w:1,h:3,places:['dining'],asset:'sideboard',category:'가구'},
 {id:'banquet-table',name:'대형 식탁',price:300,w:4,h:8,places:['dining'],asset:'banquet-table',category:'가구',surface:{w:4,h:8}},
 {id:'dining-chair',name:'다이닝 의자',price:50,w:1,h:1,places:['dining'],asset:'dining-chair',category:'가구'},
 {id:'fruit',name:'과일 플래터',price:20,w:1,h:2,places:['surface'],asset:'fruit',category:'음식'},
 {id:'tea-set',name:'티 세트',price:25,w:1,h:2,places:['surface'],asset:'tea-set',category:'음식'},
 {id:'bread',name:'빵 바구니',price:15,w:1,h:1,places:['surface'],asset:'bread',category:'음식'}
];
export const definition=id=>HOUSE_ITEMS.find(i=>i.id===id);
export function size(item){const d=definition(item.type);if(!d)throw new Error('Unknown furniture');return item.rotation%2?[d.h,d.w]:[d.w,d.h]}
export function overlap(a,b,aw,ah,bw,bh){return a.x+aw>b.x&&b.x+bw>a.x&&a.y+ah>b.y&&b.y+bh>a.y}
export function canBuild(item,items){
 const d=definition(item.type),area=AREAS[item.area];
 if(!d||!area||![item.x,item.y,item.rotation].every(Number.isInteger)||item.rotation<0||item.rotation>3)return false;
 let bounds={w:area.w,h:area.h},kind=area.kind;
 if(item.parent){const table=items.find(i=>i.uid===item.parent&&i.type==='banquet-table'&&i.area===item.area&&!i.parent);if(!table)return false;bounds=definition(table.type).surface;kind='surface'}
 if(!d.places.includes(kind))return false;
 const [w,h]=size(item);
 const margin=!item.parent&&area.kind==='practice'?1:0;
 if(item.x<margin||item.y<margin||item.x+w>bounds.w-margin||item.y+h>bounds.h-margin)return false;
 const visible=!item.parent&&VISIBLE_BUILD_BOUNDS[item.area];if(visible&&(item.x<visible.x||item.y<visible.y||item.x+w>visible.x+visible.w||item.y+h>visible.y+visible.h))return false;
 if(!item.parent){const global={x:area.x+item.x,y:area.y+item.y};if(overlap(global,STAIR,w,h,STAIR.w,STAIR.h))return false;}
 if(item.area==='hall'&&!item.parent){const corners=[[item.x,item.y],[item.x+w,item.y],[item.x+w,item.y+h],[item.x,item.y+h]].map(([x,y])=>project(area.x+x,area.y+y,1,'hall'));if(polygonsOverlap(corners,HALL_STAIR_FOOTPRINT))return false;}
 return items.filter(i=>i.uid!==item.uid&&i.area===item.area&&(i.parent||null)===(item.parent||null)).every(i=>{const [iw,ih]=size(i);return !overlap(item,i,w,h,iw,ih)});
}
export function floorItems(items,floor){return items.filter(i=>AREAS[i.area]?.floor===floor)}
export function furniturePoint(item,items){const area=AREAS[item.area];if(!item.parent)return {x:area.x+item.x,y:area.y+item.y};const table=items.find(i=>i.uid===item.parent);if(!table)return {x:0,y:0};const td=definition(table.type);let x=item.x,y=item.y;const [w,h]=size(item);if(table.rotation===1){[x,y]=[td.h-item.y-h,item.x]}else if(table.rotation===2){[x,y]=[td.w-item.x-w,td.h-item.y-h]}else if(table.rotation===3){[x,y]=[item.y,td.w-item.x-w]}return {x:area.x+table.x+x,y:area.y+table.y+y}}
export function furnitureQuad(item,items){const p=furniturePoint(item,items);let [w,h]=size(item);const table=item.parent?items.find(i=>i.uid===item.parent):null;if(table?.rotation%2)[w,h]=[h,w];return [[p.x,p.y],[p.x+w,p.y],[p.x+w,p.y+h],[p.x,p.y+h]].map(([x,y])=>{const v=project(x,y,AREAS[item.area].floor,item.area);return {x:v.x,y:v.y-(item.parent?45:0)}})}
export function spritePose(item,frame,items){return registeredSprite(item.type,frame,furnitureQuad(item,items))}
export function spriteBox(item,frame,items){if(frame.ground)return spritePose(item,frame,items).box;const p=furniturePoint(item,items);let [w,h]=size(item);const table=item.parent?items.find(i=>i.uid===item.parent):null;if(table?.rotation%2)[w,h]=[h,w];const center=project(p.x+w/2,p.y+h/2,AREAS[item.area].floor,item.area),front=project(p.x+w,p.y+h,AREAS[item.area].floor,item.area);const tile=FLOOR_ONE_PLANES[item.area]?.tx||30,calibrated=['coffee-table','elegant-sofa'].includes(item.type)&&Number.isFinite(frame.contactU),width=(w+h)*tile*(calibrated?1/.94:.90),height=width*frame.h/frame.w;return {x:calibrated?front.x-width*frame.contactU:center.x-width/2,y:front.y-height*(calibrated?frame.contactV:1)-(calibrated?0:3)-(item.parent?45:0),w:width,h:height}}
