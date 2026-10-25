/** AST Web gateway. NEW Apps Script project only: never replace the Android script.
 * Script Properties: WEB_PASSWORD, WEB_ADMIN_PASSWORD, LEGACY_API_URL, LEGACY_APP_KEY.
 * Optional: WEB_ADMIN_IDS, GAME_API_URL, GAME_APP_KEY.
 * No secret in web-config.json. No credentials accepted in URL parameters.
 */
const WEB_IDLE_MS = 30 * 24 * 60 * 60 * 1000;
const WEB_SESSION_PREFIX = 'AST_WEB_SESSION_';
const WEB_ACCESS_PREFIX = 'AST_WEB_ACCESS_';
const WEB_ADMIN_ACCESS_IDLE_MS = 15 * 60 * 1000;
const WEB_RAW_ROOT = 'https://raw.githubusercontent.com/SerenLucent/AST/main/';

function doGet() {
  // Public, non-secret marker to verify that the updated version was deployed.
  return webJson({ok:true, service:'AST Web gateway', version:1, revision:'private-web-access-v1'});
}
function doPost(e) {
  try {
    const text = e && e.postData && e.postData.contents;
    if (!text || text.length > 42 * 1024 * 1024) webFail('잘못된 요청입니다.', 'BAD_REQUEST');
    const r = JSON.parse(text);
    if (!r || Array.isArray(r) || typeof r !== 'object') webFail('잘못된 요청입니다.', 'BAD_REQUEST');
    if (r.action === 'login') return webJson(webLogin(r));
    if (r.action === 'adminAccessLogin') {
      if (!webAdmin(webId(r.loginId))) webFail('웹 관리자 계정으로 인증해 주세요.', 'FORBIDDEN');
      return webJson(webLogin(r, true));
    }
    const session = webSession(r.sessionToken);
    // The Android report token can ONLY read this report or log out.
    if (session.reportOnly && !['adminWebAccess','logout'].includes(r.action)) {
      webFail('접속 기록 조회 전용 인증입니다.', 'FORBIDDEN');
    }
    if (r.action === 'logout') {
      const lock=LockService.getScriptLock();lock.waitLock(10000);
      try {PropertiesService.getScriptProperties().deleteProperty(session.key);}
      finally {lock.releaseLock();}
      return webJson({ok:true});
    }
    let result;
    if (r.action === 'session' || r.action === 'webAccess') {
      webRecordAccess(session.user);
      result = {ok:true, profile:webProfile(session.user)};
    } else if (r.action === 'adminWebAccess') result = webAdminAccess(session.user);
    else if (r.action === 'publicConfig') {
      const source = webReadJson('remote-data/main.json');
      result = {ok:true,config:{generationOptions:source.generationOptions || [], memberGenerationColors:source.memberGenerationColors || {}}};
    } else if (r.action === 'proxy') result = webProxy(session.user, r.payload);
    else if (r.action === 'gameScore') {
      if (!r.result || r.result.type !== 'stageClear' || r.result.game !== 'timing-shooter') webFail('올바른 게임 결과가 아닙니다.');
      result = webForward('GAME_API_URL', 'GAME_APP_KEY', {loginId:session.user.loginId, result:r.result});
    } else if (r.action === 'profile') result = webUpdateProfile(session.user, r.nickname);
    else webFail('지원하지 않는 요청입니다.', 'BAD_REQUEST');
    return webJson({...result,expiresAt:session.expiresAt});
  } catch (e) {
    // Never echo request bodies, passwords, tokens or upstream response text.
    return webJson({ok:false, code:e.webCode || 'SERVER_ERROR', error:e.webCode ? e.message : '서버 연결을 확인하지 못했습니다. 잠시 후 다시 시도해 주세요.'});
  }
}
function webFail(message, code) { const e = new Error(message); e.webCode = code || 'FORBIDDEN'; throw e; }
function webJson(value) { return ContentService.createTextOutput(JSON.stringify(value)).setMimeType(ContentService.MimeType.JSON); }
function webHash(text) {
  return Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, String(text), Utilities.Charset.UTF_8)
    .map(b => (b & 255).toString(16).padStart(2,'0')).join('');
}
function webEqual(a,b) {
  const x=webHash(a), y=webHash(b); let v=0;
  for(let i=0;i<x.length;i++) v |= x.charCodeAt(i)^y.charCodeAt(i);
  return v===0;
}
function webId(id) {
  if (typeof id !== 'string') webFail('아이디와 비밀번호를 확인해 주세요.', 'LOGIN_FAILED');
  const value=id.trim().toLowerCase();
  if (!value || value.length>128 || /[\x00-\x1f\x7f]/.test(value)) webFail('아이디와 비밀번호를 확인해 주세요.', 'LOGIN_FAILED');
  return value;
}
function webAdmin(id) {
  return (PropertiesService.getScriptProperties().getProperty('WEB_ADMIN_IDS') || 'admin_naokist')
    .split(',').map(v=>v.trim().toLowerCase()).includes(id);
}
function webPassword(id) {
  const p=PropertiesService.getScriptProperties();
  const admin=webAdmin(id);
  const password=p.getProperty(admin?'WEB_ADMIN_PASSWORD':'WEB_PASSWORD');
  // Respect the passwords chosen by the owner; do not impose a minimum length.
  // Missing/empty configuration must never allow passwordless access.
  if (!password) webFail('웹 로그인 서버 설정을 관리자에게 확인해 주세요.', 'SETUP_REQUIRED');
  return password;
}
function webReadJson(path) {
  if (!/^remote-data\/[a-z0-9-]+\.json$/.test(path)) webFail('허용되지 않은 자료 경로입니다.');
  const response=UrlFetchApp.fetch(WEB_RAW_ROOT+path+'?web='+Date.now(), {muteHttpExceptions:true});
  if(response.getResponseCode()!==200) webFail('최신 팀 정보를 가져오지 못했습니다.', 'UPSTREAM_UNAVAILABLE');
  return JSON.parse(response.getContentText());
}
function webUser(id) {
  const main=webReadJson('remote-data/main.json');
  const access=main.access || {};
  const allowed=(access.allowedIds || []).map(v=>String(v).trim().toLowerCase());
  if(access.login_all!=='Y' && !allowed.includes(id)) webFail('사용할 수 없는 계정입니다.', 'UNAUTHORIZED');
  const users=webReadJson('remote-data/users.json').users || [];
  const u=users.find(u=>String(u.loginId).trim().toLowerCase()===id);
  // No arbitrary new IDs and no client-selected admin role.
  if(!u) webFail('먼저 AST에 등록된 계정으로 로그인해 주세요.', 'UNAUTHORIZED');
  return {...u,loginId:id,role:webAdmin(id)?'admin':'member',resetAt:Date.parse(access.sessionResetAt || '') || 0};
}
function webProfile(u) { return {loginId:u.loginId,nickname:u.nickname || null,role:u.role}; }
function webLogin(r, reportOnly) {
  const id=webId(r.loginId);
  if(typeof r.password!=='string' || r.password.length>1024) webFail('아이디와 비밀번호를 확인해 주세요.', 'LOGIN_FAILED');
  const lock=LockService.getScriptLock(); lock.waitLock(10000);
  try {
    const cache=CacheService.getScriptCache();
    const key='WEB_FAIL_'+webHash(id);
    if(Number(cache.get(key) || 0)>=8) webFail('로그인 시도가 많습니다. 15분 후 다시 시도해 주세요.', 'RATE_LIMITED');
    if(!webEqual(r.password,webPassword(id))) {
      cache.put(key,String(Number(cache.get(key) || 0)+1),900);
      webFail('아이디와 비밀번호를 확인해 주세요.', 'LOGIN_FAILED');
    }
    const user=webUser(id);
    cache.remove(key);
    const props=PropertiesService.getScriptProperties();
    let secret=props.getProperty('WEB_SESSION_SECRET');
    if(!secret) { secret=Utilities.getUuid()+Utilities.getUuid(); props.setProperty('WEB_SESSION_SECRET',secret); }
    const random=Utilities.getUuid()+Utilities.getUuid()+String(Date.now());
    const token=Utilities.base64EncodeWebSafe(Utilities.computeHmacSha256Signature(random,secret)).replace(/=+$/,'');
    const now=Date.now(), expiresAt=now+(reportOnly ? WEB_ADMIN_ACCESS_IDLE_MS : WEB_IDLE_MS);
    const record={id,createdAt:now,expiresAt,passwordVersion:webHash(webPassword(id)),reportOnly:reportOnly===true};
    const all=props.getProperties();
    const own=[];
    for(const [k,v] of Object.entries(all)) if(k.startsWith(WEB_SESSION_PREFIX)) {
      let s;try{s=JSON.parse(v)}catch(_){props.deleteProperty(k);continue}
      if(s.expiresAt<=now) props.deleteProperty(k);
      else if(s.id===id) own.push({key:k,...s});
    }
    // Bound storage while allowing multiple phones/home-screen installations.
    own.sort((a,b)=>a.createdAt-b.createdAt);
    while(own.length>=10) props.deleteProperty(own.shift().key);
    props.setProperty(WEB_SESSION_PREFIX+webHash(token),JSON.stringify(record));
    if (!reportOnly) webWriteAccessLocked(user, now);
    return {ok:true,sessionToken:token,expiresAt,profile:webProfile(user)};
  } finally {lock.releaseLock();}
}
function webSession(token) {
  if(typeof token!=='string' || !/^[A-Za-z0-9_-]{40,100}$/.test(token)) webFail('다시 로그인해 주세요.', 'UNAUTHORIZED');
  const p=PropertiesService.getScriptProperties(), key=WEB_SESSION_PREFIX+webHash(token);
  const raw=p.getProperty(key);
  if(!raw) webFail('다시 로그인해 주세요.', 'UNAUTHORIZED');
  const s=JSON.parse(raw),now=Date.now();
  if(s.expiresAt<=now || !webEqual(s.passwordVersion,webHash(webPassword(s.id)))) {
    p.deleteProperty(key);webFail('로그인 유효기간이 끝났습니다. 다시 로그인해 주세요.', 'UNAUTHORIZED');
  }
  const user=webUser(s.id);
  if(s.createdAt<user.resetAt) {p.deleteProperty(key);webFail('로그인이 초기화됐습니다. 다시 로그인해 주세요.', 'UNAUTHORIZED');}
  // Fetching the user can overlap a logout in another request. Recheck under
  // the same lock used by logout so a deleted session is never recreated.
  const lock=LockService.getScriptLock();lock.waitLock(10000);
  try {
    const currentRaw=p.getProperty(key);
    if(!currentRaw) webFail('다시 로그인해 주세요.', 'UNAUTHORIZED');
    const current=JSON.parse(currentRaw),renewedAt=Date.now();
    if(current.id!==s.id || current.createdAt!==s.createdAt || current.expiresAt<=renewedAt ||
      !webEqual(current.passwordVersion,webHash(webPassword(current.id)))) {
      p.deleteProperty(key);webFail('다시 로그인해 주세요.', 'UNAUTHORIZED');
    }
    const expiresAt=Math.max(current.expiresAt,renewedAt+(current.reportOnly ? WEB_ADMIN_ACCESS_IDLE_MS : WEB_IDLE_MS));
    p.setProperty(key,JSON.stringify({...current,expiresAt}));
    return {key,user,expiresAt,reportOnly:current.reportOnly===true};
  }finally{lock.releaseLock();}
}
// Private server properties only. No GitHub write, IP address, device ID,
// password or token is stored in the access record. Server time is authoritative.
function webWriteAccessLocked(user, now) {
  const p=PropertiesService.getScriptProperties(), key=WEB_ACCESS_PREFIX+webHash(user.loginId);
  let previous=0;
  try { previous=JSON.parse(p.getProperty(key) || '{}').lastAccessAt || 0; } catch (_) {}
  p.setProperty(key,JSON.stringify({loginId:user.loginId,lastAccessAt:Math.max(previous,now)}));
}
function webRecordAccess(user) {
  const lock=LockService.getScriptLock();lock.waitLock(10000);
  try {webWriteAccessLocked(user,Date.now());}finally{lock.releaseLock();}
}
function webAdminAccess(user) {
  if(user.role!=='admin') webFail('관리자만 접속 기록을 조회할 수 있습니다.', 'FORBIDDEN');
  const users=webReadJson('remote-data/users.json').users || [];
  const ids=new Set(users.map(u=>String(u.loginId).trim().toLowerCase()));
  const webAccess={};
  for(const [key,raw] of Object.entries(PropertiesService.getScriptProperties().getProperties())) {
    if(!key.startsWith(WEB_ACCESS_PREFIX)) continue;
    let record;try{record=JSON.parse(raw)}catch(_){continue}
    if(ids.has(record.loginId) && Number.isSafeInteger(record.lastAccessAt) && record.lastAccessAt>0) {
      webAccess[record.loginId]=record.lastAccessAt;
    }
  }
  return {ok:true,webAccess};
}
function webForward(urlProperty,keyProperty,payload) {
  const p=PropertiesService.getScriptProperties(),url=p.getProperty(urlProperty),key=p.getProperty(keyProperty);
  if(!url || !/^https:\/\/script\.google\.com\/macros\/s\/[A-Za-z0-9_-]+\/exec$/.test(url) || !key) {
    webFail('서버 연결 설정이 필요합니다. 관리자에게 문의해 주세요.', 'SETUP_REQUIRED');
  }
  // Whitelisted payload only. The legacy app key is injected on the SERVER.
  const response=UrlFetchApp.fetch(url,{method:'post',contentType:'application/json',
    payload:JSON.stringify({...payload,appKey:key}),followRedirects:true,muteHttpExceptions:true});
  let result;try{result=JSON.parse(response.getContentText())}catch(_){webFail('기존 AST 서버 응답을 확인하지 못했습니다.','UPSTREAM_UNAVAILABLE')}
  if(response.getResponseCode()!==200 || !result || result.ok!==true) {
    webFail('AST 서버에서 요청을 완료하지 못했습니다. 새로고침 후 다시 시도해 주세요.','UPSTREAM_UNAVAILABLE');
  }
  return result;
}
function webCanonical(value) {
  if(Array.isArray(value)) return '['+value.map(webCanonical).join(',')+']';
  if(value && typeof value==='object') return '{'+Object.keys(value).sort()
    .map(k=>JSON.stringify(k)+':'+webCanonical(value[k])).join(',')+'}';
  return JSON.stringify(value);
}
function webOwnEntries(user,path,content) {
  const field=path==='remote-data/schedule.json'?'schedules':'notices';
  if(!content || !Array.isArray(content[field])) webFail('올바른 저장 내용이 아닙니다.');
  const before=webReadJson(path)[field] || [],after=content[field];
  const byId=new Map();
  for(const row of after) {
    if(!row || typeof row.id!=='string' || !row.id || byId.has(row.id)) webFail('중복되거나 올바르지 않은 항목입니다.');
    byId.set(row.id,row);
  }
  for(const row of before) {
    const next=byId.get(row.id);
    if(row.authorId!==user.loginId && webCanonical(next)!==webCanonical(row)) webFail('다른 사람이 작성한 항목은 변경할 수 없습니다.');
    if(row.authorId===user.loginId && next && next.authorId!==user.loginId) webFail('작성자를 바꿀 수 없습니다.');
    byId.delete(row.id);
  }
  for(const row of byId.values()) if(row.authorId!==user.loginId) webFail('본인 계정으로만 작성할 수 있습니다.');
}
function webProxy(user,payload) {
  if(!payload || typeof payload!=='object' || Array.isArray(payload)) webFail('잘못된 요청입니다.');
  const r=payload, action=r.action,admin=user.role==='admin';
  let out;
  if(action==='astWalletGet') out={action,loginId:user.loginId};
  else if(action==='astWalletClaim') out={action,loginId:user.loginId,requestId:r.requestId,expectedAvailableAt:r.expectedAvailableAt};
  else if(action==='astHomeGet') out={action,loginId:user.loginId};
  else if(action==='astHomeApply') {
    if(r.accountKey!==webHash(user.loginId)) webFail('구매 계정이 다릅니다. 다시 입장해 주세요.');
    out={...r,action,loginId:user.loginId}; delete out.appKey;delete out.sessionToken;
  } else if(action==='saveJson') {
    const paths=['remote-data/schedule.json','remote-data/board.json','remote-data/notices.json','remote-data/members.json','remote-data/generations.json','remote-data/users.json'];
    if(!paths.includes(r.path)) webFail('허용되지 않은 저장 경로입니다.');
    if(!admin) {
      if(!['remote-data/schedule.json','remote-data/board.json'].includes(r.path)) webFail('관리자 권한이 필요합니다.');
      webOwnEntries(user,r.path,r.content);
    }
    out={path:r.path,content:r.content,message:'AST Web: '+String(r.message || '업데이트').slice(0,120)};
  } else if(action==='upload') {
    const extensions={Music:['pdf'],Doc:['pdf','ppt','pptx','doc','docx'],Image:['jpg','jpeg','png','webp']};
    if(!extensions[r.folder] || typeof r.fileName!=='string' || /[\\/\x00-\x1f]/.test(r.fileName) ||
      !extensions[r.folder].includes(r.fileName.split('.').pop().toLowerCase())) webFail('허용되지 않은 파일입니다.');
    if(!admin && !(r.folder==='Music' && user.canUploadScores===true) && !(r.folder==='Doc' && user.canUploadHistory===true)) webFail('업로드 권한이 없습니다.');
    if(typeof r.contentBase64!=='string' || r.contentBase64.length>40*1024*1024) webFail('파일 크기를 확인해 주세요.');
    out={action,folder:r.folder,fileName:r.fileName,contentBase64:r.contentBase64,message:'AST Web upload',existingSha:r.existingSha};
  } else if(action==='delete') {
    if(!admin || typeof r.path!=='string' || !/^Music\/[^/\\]+\.pdf$/i.test(r.path) || r.path.includes('..')) webFail('삭제 권한 또는 경로를 확인해 주세요.');
    out={action,path:r.path,sha:r.sha,message:'AST Web delete'};
  } else webFail('허용되지 않은 작업입니다.');
  return webForward('LEGACY_API_URL','LEGACY_APP_KEY',out);
}
function webUpdateProfile(user,nickname) {
  if(typeof nickname!=='string' || !nickname.trim() || nickname.trim().length>40 || /[\x00-\x1f]/.test(nickname)) webFail('이름을 확인해 주세요.');
  const lock=LockService.getScriptLock();lock.waitLock(10000);
  try {
    const data=webReadJson('remote-data/users.json');
    const index=data.users.findIndex(u=>String(u.loginId).toLowerCase()===user.loginId);
    if(index<0) webFail('등록된 계정이 없습니다.');
    data.users[index]={...data.users[index],nickname:nickname.trim()};
    webForward('LEGACY_API_URL','LEGACY_APP_KEY',{path:'remote-data/users.json',content:data,message:'AST Web own profile'});
    return {ok:true,profile:webProfile({...user,nickname:nickname.trim()})};
  }finally{lock.releaseLock();}
}
