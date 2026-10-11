const pending=new Map();
window.astHomeResponse=({id,result,error})=>{const p=pending.get(id);if(!p)return;clearTimeout(p.timer);pending.delete(id);error?p.reject(new Error(error)):p.resolve(result)};
export function request(payload){return new Promise((resolve,reject)=>{if(!window.AstHome?.postMessage){reject(new Error('AST 앱에서 게임을 열어 주세요.'));return}const id=crypto.randomUUID();const timer=setTimeout(()=>{pending.delete(id);reject(new Error('서버 응답 시간이 초과되었습니다.'));},45000);pending.set(id,{resolve,reject,timer});window.AstHome.postMessage(JSON.stringify({id,payload}));})}
