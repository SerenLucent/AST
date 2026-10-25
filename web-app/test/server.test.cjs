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
  return {properties,forwards,data,advance:ms=>now+=ms,onRead:fn=>afterRead=fn,health:()=>context.doGet(),
    call:r=>context.doPost({postData:{contents:JSON.stringify(r)}}),
    login:(id='alice',password='web-test-password-only')=>context.doPost({postData:{contents:JSON.stringify({action:'login',loginId:id,password})}})};
}
test('login issues only opaque token and server profile, not app key/password',()=>{
  const h=harness(),r=h.login();assert.equal(r.ok,true);assert.equal(r.profile.loginId,'alice');
  assert.match(r.sessionToken,/^[A-Za-z0-9_-]{43}$/);assert.ok(!JSON.stringify(r).includes('test-key'));
  assert.ok(!JSON.stringify(r).includes('password'));assert.equal(r.expiresAt,1000000000000+30*86400000);
});
test('member login and restore use the configured password without a minimum length',()=>{
  for(const length of [1,9,10,11,12]) {
    const h=harness(),password='A'.repeat(length);
    h.properties.set('WEB_PASSWORD',password);
    const r=h.login('alice',password);
    assert.equal(r.ok,true);assert.equal(r.profile.role,'member');
    assert.equal(h.call({action:'session',sessionToken:r.sessionToken}).ok,true);
    assert.equal(h.login('alice','B'.repeat(length)).code,'LOGIN_FAILED');
  }
});
test('missing or empty member/admin password is rejected without creating a session',()=>{
  for(const [id,property] of [['alice','WEB_PASSWORD'],['admin_naokist','WEB_ADMIN_PASSWORD']]) {
    for(const missing of [true,false]) {
      const h=harness();
      if(missing) h.properties.delete(property);else h.properties.set(property,'');
      assert.equal(h.login(id,'').code,'SETUP_REQUIRED');
      assert.equal(h.forwards.length,0);
      assert.equal([...h.properties.keys()].some(k=>k.startsWith('AST_WEB_SESSION_')),false);
    }
  }
});
test('administrator login and restore also have no minimum password length',()=>{
  for(const length of [1,9,10,11,12]) {
    const h=harness(),password='A'.repeat(length);
    h.properties.set('WEB_ADMIN_PASSWORD',password);
    const r=h.login('admin_naokist',password);
    assert.equal(r.ok,true);assert.equal(r.profile.role,'admin');
    assert.equal(h.call({action:'session',sessionToken:r.sessionToken}).ok,true);
    assert.equal(h.login('admin_naokist','B'.repeat(length)).code,'LOGIN_FAILED');
  }
});
test('public health identifies the deployed revision without exposing properties',()=>{
  const h=harness(),health=h.health();
  assert.deepEqual(health,{ok:true,service:'AST Web gateway',version:1,revision:'private-web-access-v1'});
  assert.ok(!JSON.stringify(health).includes(h.properties.get('WEB_PASSWORD')));
  assert.ok(!JSON.stringify(health).includes(h.properties.get('WEB_ADMIN_PASSWORD')));
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

function accessRecords(h) {
  return [...h.properties.entries()].filter(([key])=>key.startsWith('AST_WEB_ACCESS_')).map(([,raw])=>JSON.parse(raw));
}
test('web login and restore record server time privately without a GitHub write',()=>{
  const h=harness(),original=JSON.stringify(h.data),r=h.login();
  assert.deepEqual(accessRecords(h),[{loginId:'alice',lastAccessAt:1000000000000}]);
  h.advance(3600000);
  assert.equal(h.call({action:'session',sessionToken:r.sessionToken}).ok,true);
  assert.deepEqual(accessRecords(h),[{loginId:'alice',lastAccessAt:1000003600000}]);
  assert.equal(h.forwards.length,0);assert.equal(JSON.stringify(h.data),original);
});
test('foreground access uses verified identity and ignores client timestamp',()=>{
  const h=harness(),r=h.login();h.advance(5000);
  assert.equal(h.call({action:'webAccess',sessionToken:r.sessionToken,loginId:'bob',lastAccessAt:9999999999999}).ok,true);
  assert.deepEqual(accessRecords(h),[{loginId:'alice',lastAccessAt:1000000005000}]);
});
test('failed login and rejected session never create access records',()=>{
  const h=harness();h.login('alice','bad');
  h.call({action:'webAccess',sessionToken:'x'.repeat(43)});
  assert.deepEqual(accessRecords(h),[]);
});
test('only a verified admin can read web access; public health exposes none',()=>{
  const h=harness(),member=h.login();
  assert.equal(h.call({action:'adminWebAccess',sessionToken:member.sessionToken,role:'admin'}).code,'FORBIDDEN');
  const admin=h.login('admin_naokist','admin-test-password-only');
  const r=h.call({action:'adminWebAccess',sessionToken:admin.sessionToken});
  assert.equal(r.webAccess.alice,1000000000000);
  assert.equal(h.health().webAccess,undefined);
  for(const secret of ['test-password','test-key','sessionToken']) assert.ok(!JSON.stringify(r).includes(secret));
});
test('Android admin report authentication does not count as web usage and cannot mutate',()=>{
  const h=harness();h.login();
  const r=h.call({action:'adminAccessLogin',loginId:'admin_naokist',password:'admin-test-password-only'});
  assert.equal(r.ok,true);assert.equal(r.expiresAt,1000000000000+15*60000);
  assert.equal(h.call({action:'adminWebAccess',sessionToken:r.sessionToken}).ok,true);
  assert.deepEqual(accessRecords(h),[{loginId:'alice',lastAccessAt:1000000000000}]);
  for(const action of ['proxy','webAccess','session','gameScore','profile']) {
    assert.equal(h.call({action,sessionToken:r.sessionToken,payload:{action:'astWalletClaim'}}).code,'FORBIDDEN');
  }
  assert.equal(h.forwards.length,0);
  assert.equal(h.call({action:'logout',sessionToken:r.sessionToken}).ok,true);
  assert.equal(h.call({action:'adminWebAccess',sessionToken:r.sessionToken}).code,'UNAUTHORIZED');
});
test('member cannot request Android admin report token',()=>{
  const h=harness();
  assert.equal(h.call({action:'adminAccessLogin',loginId:'alice',password:'web-test-password-only'}).code,'FORBIDDEN');
  assert.deepEqual(accessRecords(h),[]);
});
test('report session expires after 15 minutes idle; changing admin password revokes it',()=>{
  const h=harness();const login=()=>h.call({action:'adminAccessLogin',loginId:'admin_naokist',password:'admin-test-password-only'});
  let r=login();h.advance(15*60000);
  assert.equal(h.call({action:'adminWebAccess',sessionToken:r.sessionToken}).code,'UNAUTHORIZED');
  r=login();h.properties.set('WEB_ADMIN_PASSWORD','changed');
  assert.equal(h.call({action:'adminWebAccess',sessionToken:r.sessionToken}).code,'UNAUTHORIZED');
});
test('report excludes deleted users and survives logout',()=>{
  const h=harness(),alice=h.login();h.login('bob');
  h.call({action:'logout',sessionToken:alice.sessionToken});
  h.data['remote-data/users.json'].users=h.data['remote-data/users.json'].users.filter(u=>u.loginId!=='bob');
  const admin=h.call({action:'adminAccessLogin',loginId:'admin_naokist',password:'admin-test-password-only'});
  const r=h.call({action:'adminWebAccess',sessionToken:admin.sessionToken});
  assert.deepEqual(r.webAccess,{alice:1000000000000});
});
