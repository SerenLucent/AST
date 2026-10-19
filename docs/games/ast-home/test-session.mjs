export const TEST_KEY='ast-home-test-v1';
export function readTestState(storage){
 try{const s=JSON.parse(storage.getItem(TEST_KEY));if(s&&Number.isSafeInteger(s.coins)&&s.coins>=0&&Array.isArray(s.items))return s}catch{}
 const s={coins:10000,items:[]};try{storage.setItem(TEST_KEY,JSON.stringify(s))}catch{}return s;
}
export function mountTestTools(){
 const bar=document.createElement('aside');bar.className='test-banner';
 const label=document.createElement('span');label.textContent='TEST · 최초 10,000 AST · 이 브라우저에만 저장';
 const reset=document.createElement('button');reset.textContent='테스트 초기화 · 10,000 AST';
 reset.onclick=()=>{try{localStorage.removeItem(TEST_KEY);location.reload()}catch{label.textContent='브라우저 저장 설정을 확인하세요.'}};
 bar.append(label,reset);document.body.prepend(bar);
}
