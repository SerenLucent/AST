import {registeredSprite} from './sprite-geometry.mjs?v=20261019-planes1';
export const COLS=12,ROWS=20;
export const BUILD_ROWS=14; // Six rows behind the foreground wall are unavailable.
export const origin={x:600,y:260},a={x:-40,y:20},b={x:40,y:20};
export function point(x,y){return {x:origin.x+a.x*x+b.x*y,y:origin.y+a.y*x+b.y*y}}
export const floorCorners=[point(0,0),point(COLS,0),point(COLS,ROWS),point(0,ROWS)];
export function cell(p){const x=p.x-origin.x,y=p.y-origin.y;return {x:Math.floor((-x/40+y/20)/2+1e-8),y:Math.floor((x/40+y/20)/2+1e-8)}}
export const catalog=[
 {id:'wardrobe',name:'장롱',price:50,w:1,h:2},
 {id:'table',name:'식탁',price:100,w:2,h:3},
 {id:'chair',name:'의자',price:30,w:1,h:1},
 {id:'sofa',name:'소파',price:150,w:1,h:3},
 {id:'plant',name:'화분',price:40,w:1,h:1},
 {id:'bookshelf',name:'책장',price:80,w:1,h:2},
 {id:'coffee-table',name:'커피 테이블',price:60,w:2,h:3}
];
export function footprint(item){const t=catalog.find(t=>t.id===item.type);return item.rotation%2?[t.h,t.w]:[t.w,t.h]}
export function canPlace(item,items){const [w,h]=footprint(item);if(item.x<0||item.y<0||item.x+w>COLS||item.y+h>BUILD_ROWS)return false;return items.filter(i=>!i.area&&i.uid!==item.uid).every(i=>{const [iw,ih]=footprint(i);return item.x+w<=i.x||i.x+iw<=item.x||item.y+h<=i.y||i.y+ih<=item.y})}
export function spriteLayout(item,frame){const [w,h]=footprint(item),corners=[point(item.x,item.y),point(item.x+w,item.y),point(item.x+w,item.y+h),point(item.x,item.y+h)];if(frame.ground)return registeredSprite(item.type,frame,corners).box;const left=Math.min(...corners.map(p=>p.x)),right=Math.max(...corners.map(p=>p.x)),bottom=Math.max(...corners.map(p=>p.y));const width=(right-left)*.9,height=width*frame.h/frame.w;return {x:(left+right-width)/2,y:bottom-4-height,w:width,h:height}}
export function migrateLayout(items){const placed=[];for(const item of items){let next={...item};if(!canPlace(next,placed)){let found=false;for(let y=0;y<BUILD_ROWS&&!found;y++)for(let x=0;x<COLS&&!found;x++){const candidate={...item,x,y};if(canPlace(candidate,placed)){next=candidate;found=true}}if(!found)throw new Error('배치할 공간이 부족합니다.');}placed.push(next)}return placed}
