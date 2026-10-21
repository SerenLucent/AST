const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const crypto = require('node:crypto');
function harness() {
  let now=1000000000000;
  const properties = new Map(Object.entries({WEB_PASSWORD:'web-test-password-only',WEB_ADMIN_PASSWORD:'admin-test-password-only',
    LEGACY_API_URL:'https://script.google.com/macros/s/legacy/exec',LEGACY_APP_KEY:'server-only-test-key',
    GAME_API_URL:'https://script.google.com/macros/s/game/exec',GAME_APP_KEY:'server-only-game-key'}));
  const cache=new Map(), forwards=[];
  let afterRead=null;
  const data={
    'remote-data/main.json':{access:{login_all:'N',allowedIds:['alice','bob','admin_naokist'],teamPassword:'legacy-must-not-leak'},generationOptions:[]},
    'remote-data/users.json':{users:[{loginId:'alice',nickname:'Alice',canUploadScores:true},{loginId:'bob',nickname:'Bob'},{loginId:'admin_naokist',nickname:'Admin'}]},
    'remote-data/schedule.json':{schedules:[{id:'a',authorId:'alice',title:'Mine'},{id:'b',authorId:'bob',title:'Other'}]},
    'remote-data/board.json':{notices:[]},
  };
  const context={Date:class extends Date {static now(){return now}},
    ContentService:{MimeType:{JSON:'json'},createTextOutput:text=>({setMimeType:()=>JSON.parse(text)})},
    PropertiesService:{getScriptProperties:()=>({getProperty:k=>properties.get(k)||null,setProperty:(k,v)=>properties.set(k,v),deleteProperty:k=>properties.delete(k),getProperties:()=>Object.fromEntries(properties)})},
    CacheService:{getScriptCache:()=>({get:k=>cache.get(k)||null,put:(k,v)=>cache.set(k,v),remove:k=>cache.delete(k)})},
    LockService:{getScriptLock:()=>({waitLock(){},releaseLock(){}})},
    Utilities:{DigestAlgorithm:{SHA_256:'sha256'},Charset:{UTF_8:'utf8'},getUuid:crypto.randomUUID,
      computeDigest:(alg,v)=>[...crypto.createHash(alg).update(v).digest()],
      computeHmacSha256Signature:(v,key)=>[...crypto.createHmac('sha256',key).update(v).digest()],
      base64EncodeWebSafe:b=>Buffer.from(b).toString('base64url')},
    UrlFetchApp:{fetch(url,options){
      if(url.includes('raw.githubusercontent.com')) {
        const path=url.split('/main/')[1].split('?')[0];
        if(afterRead) afterRead(path);
        return {getResponseCode:()=>data[path]?200:404,getContentText:()=>JSON.stringify(data[path]||{})};
      }
      const payload=JSON.parse(options.payload);forwards.push(payload);
      if(payload.path) data[payload.path]=payload.content;
      return {getResponseCode:()=>200,getContentText:()=>JSON.stringify({ok:true,status:'synced',wallet:{balance:17}})};
    }},
  };
  vm.createContext(context);
  vm.runInContext(fs.readFileSync(require.resolve('../server/Code.gs'),'utf8'),context);
  return {properties,forwards,data,advance:ms=>now+=ms,onRead:fn=>afterRead=fn,
    call:r=>context.doPost({postData:{contents:JSON.stringify(r)}}),
    login:(id='alice',password='web-test-password-only')=>context.doPost({postData:{contents:JSON.stringify({action:'login',loginId:id,password})}})};
}
test('login issues only opaque token and server profile, not app key/password',()=>{
  const h=harness(),r=h.login();assert.equal(r.ok,true);assert.equal(r.profile.loginId,'alice');
  assert.match(r.sessionToken,/^[A-Za-z0-9_-]{43}$/);assert.ok(!JSON.stringify(r).includes('test-key'));
  assert.ok(!JSON.stringify(r).includes('password'));assert.equal(r.expiresAt,1000000000000+30*86400000);
});
test('11-character shared member password supports login and session restore',()=>{
  const h=harness(),password='A'.repeat(11);
  h.properties.set('WEB_PASSWORD',password);
  const r=h.login('alice',password);
  assert.equal(r.ok,true);assert.equal(r.profile.role,'member');
  assert.equal(h.call({action:'session',sessionToken:r.sessionToken}).ok,true);
  assert.equal(h.login('alice','B'.repeat(11)).code,'LOGIN_FAILED');
});
test('missing or shorter-than-11 member password remains invalid configuration',()=>{
  for(const password of ['', 'A'.repeat(10)]) {
    const h=harness();h.properties.set('WEB_PASSWORD',password);
    assert.equal(h.login('alice',password).code,'SETUP_REQUIRED');
    assert.equal(h.forwards.length,0);
  }
});
test('administrator password requirement is unchanged',()=>{
  const h=harness();h.properties.set('WEB_ADMIN_PASSWORD','A'.repeat(11));
  assert.equal(h.login('admin_naokist','A'.repeat(11)).code,'SETUP_REQUIRED');
  h.properties.set('WEB_ADMIN_PASSWORD','A'.repeat(12));
  const r=h.login('admin_naokist','A'.repeat(12));
  assert.equal(r.ok,true);assert.equal(r.profile.role,'admin');
});
test('wrong password and forged token cannot query or mutate',()=>{
  const h=harness();assert.equal(h.login('alice','bad').ok,false);
  const r=h.call({action:'proxy',sessionToken:'x'.repeat(43),payload:{action:'astWalletClaim',loginId:'bob'}});
  assert.equal(r.code,'UNAUTHORIZED');assert.equal(h.forwards.length,0);
});
test('existing login restores across clients and sliding expiry advances',()=>{
  const h=harness(),r=h.login();h.advance(29*86400000);
  const restored=h.call({action:'session',sessionToken:r.sessionToken});assert.equal(restored.ok,true);
  assert.ok(restored.expiresAt>r.expiresAt);h.advance(29*86400000);
  assert.equal(h.call({action:'session',sessionToken:r.sessionToken}).ok,true);
});
test('30 days inactivity expires, logout invalidates, password change revokes',()=>{
  let h=harness(),r=h.login();h.advance(30*86400000);
  assert.equal(h.call({action:'session',sessionToken:r.sessionToken}).code,'UNAUTHORIZED');
  h=harness();r=h.login();assert.equal(h.call({action:'logout',sessionToken:r.sessionToken}).ok,true);
  assert.equal(h.call({action:'session',sessionToken:r.sessionToken}).code,'UNAUTHORIZED');
  r=h.login();h.properties.set('WEB_PASSWORD','new-private-web-password');
  assert.equal(h.call({action:'session',sessionToken:r.sessionToken}).code,'UNAUTHORIZED');
});
test('client loginId and appKey cannot select another wallet',()=>{
  const h=harness(),r=h.login();h.call({action:'proxy',sessionToken:r.sessionToken,payload:{action:'astWalletGet',loginId:'bob',appKey:'forged'}});
  assert.equal(h.forwards.at(-1).loginId,'alice');assert.equal(h.forwards.at(-1).appKey,'server-only-test-key');
});
test('member cannot elevate to admin or write users / arbitrary paths',()=>{
  const h=harness();assert.equal(h.login('admin_naokist').ok,false);
  const r=h.login();for(const path of ['remote-data/users.json','remote-data/main.json','../../config']) {
    assert.equal(h.call({action:'proxy',sessionToken:r.sessionToken,payload:{action:'saveJson',path,content:{},role:'admin'}}).ok,false);
  }
  assert.equal(h.forwards.length,0);
});
test('account-bound house mutations reject another account',()=>{
  const h=harness(),r=h.login();
  assert.equal(h.call({action:'proxy',sessionToken:r.sessionToken,payload:{action:'astHomeApply',accountKey:'bob'}}).ok,false);
  assert.equal(h.forwards.length,0);
});
test('publicConfig never returns legacy access credentials',()=>{
  const h=harness(),r=h.login(),result=h.call({action:'publicConfig',sessionToken:r.sessionToken});
  assert.equal(result.ok,true);assert.equal(result.config.access,undefined);assert.ok(!JSON.stringify(result).includes('legacy-must-not-leak'));
});
test('removed member and reset timestamp invalidate existing login',()=>{
  const h=harness(),r=h.login();h.data['remote-data/main.json'].access.allowedIds=[];
  assert.equal(h.call({action:'session',sessionToken:r.sessionToken}).code,'UNAUTHORIZED');
  h.data['remote-data/main.json'].access.allowedIds=['alice'];
  h.data['remote-data/main.json'].access.sessionResetAt=new Date(1000000000001).toISOString();
  assert.equal(h.call({action:'session',sessionToken:r.sessionToken}).code,'UNAUTHORIZED');
});
test('own schedule changes allowed, others cannot be deleted or forged',()=>{
  const h=harness(),r=h.login(),payload={action:'saveJson',path:'remote-data/schedule.json',content:{schedules:[{id:'a',authorId:'alice',title:'Updated'},{id:'b',authorId:'bob',title:'Other'}]}};
  assert.equal(h.call({action:'proxy',sessionToken:r.sessionToken,payload}).ok,true);
  payload.content.schedules.pop();assert.equal(h.call({action:'proxy',sessionToken:r.sessionToken,payload}).ok,false);
});
test('profile update only changes current user, not permissions',()=>{
  const h=harness(),r=h.login(),result=h.call({action:'profile',sessionToken:r.sessionToken,loginId:'bob',role:'admin',nickname:'New name'});
  assert.equal(result.profile.loginId,'alice');assert.equal(result.profile.role,'member');
  assert.equal(h.data['remote-data/users.json'].users[1].nickname,'Bob');
});
test('login throttled after eight wrong attempts',()=>{
  const h=harness();for(let i=0;i<8;i++)h.login('alice','wrong');assert.equal(h.login().code,'RATE_LIMITED');
});
test('session revoked while checking membership is not recreated',()=>{
  const h=harness(),r=h.login();
  h.onRead(()=>{for(const key of h.properties.keys())if(key.startsWith('AST_WEB_SESSION_'))h.properties.delete(key)});
  assert.equal(h.call({action:'session',sessionToken:r.sessionToken}).code,'UNAUTHORIZED');
  assert.equal([...h.properties.keys()].filter(k=>k.startsWith('AST_WEB_SESSION_')).length,0);
});
test('property order does not reject unchanged entries owned by others',()=>{
  const h=harness(),r=h.login();
  const payload={action:'saveJson',path:'remote-data/schedule.json',content:{schedules:[
    {id:'a',authorId:'alice',title:'Updated'}, {title:'Other',authorId:'bob',id:'b'}]}};
  assert.equal(h.call({action:'proxy',sessionToken:r.sessionToken,payload}).ok,true);
  payload.content.schedules[1].title='Forged';
  assert.equal(h.call({action:'proxy',sessionToken:r.sessionToken,payload}).ok,false);
});
