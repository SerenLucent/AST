// DEPLOY THIS ENTIRE FILE by replacing the existing Apps Script Code.gs.
// Do not add it beside the old Code.gs (duplicate handlers/constants).
// Wallet revision: github-first-claim-v3

const OWNER = 'SerenLucent';
const REPOSITORY = 'AST';
const BRANCH = 'main';

const ALLOWED_JSON_PATHS = [
  'remote-data/schedule.json',
  'remote-data/generations.json',
  'remote-data/members.json',
  'remote-data/users.json',
  'remote-data/notices.json',
  'remote-data/board.json',
];

const ALLOWED_UPLOADS = {
  Music: ['pdf'],
  Doc: ['pdf', 'ppt', 'pptx', 'doc', 'docx'],
  Image: ['jpg', 'jpeg', 'png', 'webp'],
};

function doGet() {
  return jsonResponse({
    ok: true,
    service: 'AST GitHub API',
    walletPolicy: AST_WALLET_POLICY,
    walletStorage: 'github',
  });
}

function doPost(e) {
  const lock = LockService.getScriptLock();

  try {
    const properties = PropertiesService.getScriptProperties();
    const githubToken = properties.getProperty('GITHUB_TOKEN');
    const appKey = properties.getProperty('APP_KEY');

    if (!githubToken || !appKey) {
      return jsonResponse({ ok: false, error: '서버 설정이 완료되지 않았습니다.' });
    }

    const request = JSON.parse(e.postData.contents || '{}');
    if (request.appKey !== appKey) {
      return jsonResponse({ ok: false, error: '인증에 실패했습니다.' });
    }

    if (request.action === 'validate') {
      return validateGithub(githubToken);
    }

    lock.waitLock(30000);

    if (request.action === 'astHomeGet' || request.action === 'astHomeApply') return homeRequest(properties, githubToken, request);
    if (request.action === 'astWalletGet' || request.action === 'astWalletClaim') homeRecover(properties, githubToken);

    // Wallet values are persisted in GitHub through this server, not the app.
    // This uses the existing app-key/login-ID trust model, not per-user sessions.
    if (request.action === 'astWalletGet' || request.action === 'astWalletClaim') {
      return astWalletRequest(properties, request, githubToken);
    }

    if (request.action === 'upload') {
      return uploadFile(githubToken, request);
    }
    if (request.action === 'delete') {
      return deleteFile(githubToken, request);
    }
    return saveJsonFile(githubToken, request);
  } catch (error) {
    return jsonResponse({ ok: false, error: String(error) });
  } finally {
    try {
      lock.releaseLock();
    } catch (_) {}
  }
}

const AST_REWARD = 10;
const AST_INTERVAL_MS = 60 * 60 * 1000;
const AST_WALLET_PREFIX = 'AST_WALLET_V1_';
const AST_WALLET_POLICY = 'github-first-claim-v3';
const AST_WALLET_GITHUB_PREFIX = 'remote-data/ast-wallets/';
const AST_WALLET_MIGRATED_PREFIX = 'AST_WALLET_GITHUB_V1_';

// Must only be called under the doPost ScriptLock. Server time is authoritative.
function astWalletRequest(properties, request, githubToken) {
  const loginId = String(request.loginId || '').trim().toLowerCase();
  if (!loginId || loginId.length > 128 || /[\x00-\x1f\x7f]/.test(loginId)) {
    throw new Error('올바른 로그인 아이디가 필요합니다.');
  }
  const isClaim = request.action === 'astWalletClaim';
  if (isClaim && (
    typeof request.requestId !== 'string' ||
    !/^[a-zA-Z0-9_-]{16,80}$/.test(request.requestId) ||
    !Number.isSafeInteger(request.expectedAvailableAt)
  )) {
    throw new Error('올바른 수령 요청이 필요합니다.');
  }
  const key = AST_WALLET_PREFIX + encodeURIComponent(loginId);
  const accountHash = astAccountHash(loginId);
  const markerKey = AST_WALLET_MIGRATED_PREFIX + accountHash;
  const stored = readAstGithubWallet(githubToken, accountHash, loginId);
  const now = Date.now();
  let wallet = stored.wallet;
  let needsSave = false;
  if (wallet === null) {
    // A missing migrated file must never restore stale private balances.
    if (properties.getProperty(markerKey) !== null) {
      throw new Error('GitHub 아스트 기록이 없습니다. 관리자에게 복구를 요청해 주세요.');
    }
    const legacyRaw = properties.getProperty(key);
    if (legacyRaw !== null) {
      wallet = JSON.parse(legacyRaw);
      validateAstWallet(wallet, loginId);
    } else {
      if (isClaim) throw new Error('아스트 정보를 먼저 새로고침해 주세요.');
      wallet = {
        schemaVersion: 1,
        loginId: loginId,
        balance: 0,
        // Full UI gauge for the existing APK; NOT a fabricated receipt.
        cycleStartedAt: now - AST_INTERVAL_MS,
        availableAt: now,
        lastClaimedAt: null,
        lastRequestId: null,
      };
    }
    needsSave = true;
  }
  // Missing receipt means no wait, including legacy first-login cooldowns.
  // A zero balance alone must never reset a previously received account.
  if (wallet.lastClaimedAt === null && wallet.availableAt > now) {
    wallet.cycleStartedAt = now - AST_INTERVAL_MS;
    wallet.availableAt = now;
    needsSave = true;
  }

  let status = 'synced';
  if (isClaim) {
    if (request.requestId === wallet.lastRequestId ||
        request.expectedAvailableAt !== wallet.availableAt) {
      status = 'already_claimed';
    } else if (now < wallet.availableAt) {
      status = 'waiting';
    } else {
      if (!Number.isSafeInteger(wallet.balance + AST_REWARD)) {
        throw new Error('아스트 잔액을 확인해 주세요.');
      }
      wallet.balance += AST_REWARD;
      wallet.cycleStartedAt = now;
      wallet.availableAt = now + AST_INTERVAL_MS;
      wallet.lastClaimedAt = now;
      wallet.lastRequestId = request.requestId;
      needsSave = true;
      status = 'claimed';
    }
  }
  // Credit, receipt and deduplication token are committed together with a
  // conditional SHA update. Never report success before GitHub saves them.
  if (needsSave) {
    saveAstGithubWallet(githubToken, accountHash, wallet, stored.sha);
  }
  if (properties.getProperty(markerKey) === null) {
    // Metadata only. Keep the old private record unchanged as a backup;
    // GitHub is authoritative after migration.
    properties.setProperty(markerKey, '1');
  }
  return jsonResponse({
    ok: true,
    status: status,
    reward: AST_REWARD,
    walletPolicy: AST_WALLET_POLICY,
    walletStorage: 'github',
    intervalSeconds: AST_INTERVAL_MS / 1000,
    serverNow: Date.now(),
    wallet: {
      schemaVersion: wallet.schemaVersion,
      loginId: wallet.loginId,
      balance: wallet.balance,
      cycleStartedAt: wallet.cycleStartedAt,
      availableAt: wallet.availableAt,
      lastClaimedAt: wallet.lastClaimedAt,
    },
  });
}

function astAccountHash(loginId) {
  // Stable identifier, not encryption: public repositories expose wallet data.
  // Avoid putting the original login ID in a public filename or JSON record.
  return Utilities.computeDigest(
    Utilities.DigestAlgorithm.SHA_256, loginId, Utilities.Charset.UTF_8
  ).map(byte => ('0' + (byte & 255).toString(16)).slice(-2)).join('');
}

function readAstGithubWallet(token, accountHash, loginId) {
  const path = AST_WALLET_GITHUB_PREFIX + accountHash + '.json';
  const response = UrlFetchApp.fetch(
    contentsUrl(path) + '?ref=' + encodeURIComponent(BRANCH),
    {
      method: 'get',
      headers: Object.assign({}, githubHeaders(token), { 'Cache-Control': 'no-cache' }),
      muteHttpExceptions: true,
    }
  );
  const status = response.getResponseCode();
  if (status === 404) return { wallet: null, sha: null };
  if (status !== 200) {
    throw new Error('GitHub 아스트 기록 조회에 실패했습니다. 잠시 후 다시 시도해 주세요. (' + status + ')');
  }
  const body = JSON.parse(response.getContentText());
  if (body.type !== 'file' || body.encoding !== 'base64' ||
      typeof body.content !== 'string' || body.size > 16384 ||
      typeof body.sha !== 'string' || !body.sha) {
    throw new Error('GitHub 아스트 기록 형식을 확인해 주세요.');
  }
  const record = JSON.parse(Utilities.newBlob(
    Utilities.base64Decode(body.content.replace(/\s/g, ''))
  ).getDataAsString('UTF-8'));
  if (!record || record.accountHash !== accountHash) {
    throw new Error('GitHub 아스트 계정 정보가 일치하지 않습니다.');
  }
  const wallet = {
    schemaVersion: record.schemaVersion,
    loginId: loginId,
    balance: record.balance,
    cycleStartedAt: record.cycleStartedAt,
    availableAt: record.availableAt,
    lastClaimedAt: record.lastClaimedAt,
    lastRequestId: record.lastRequestId,
  };
  validateAstWallet(wallet, loginId);
  return { wallet: wallet, sha: body.sha };
}

function saveAstGithubWallet(token, accountHash, wallet, sha) {
  const record = {
    schemaVersion: 1,
    accountHash: accountHash,
    balance: wallet.balance,
    cycleStartedAt: wallet.cycleStartedAt,
    availableAt: wallet.availableAt,
    lastClaimedAt: wallet.lastClaimedAt,
    lastRequestId: wallet.lastRequestId,
  };
  const payload = {
    message: 'AST wallet update',
    branch: BRANCH,
    content: Utilities.base64Encode(JSON.stringify(record, null, 2), Utilities.Charset.UTF_8),
  };
  if (sha) payload.sha = sha;
  const response = UrlFetchApp.fetch(contentsUrl(
    AST_WALLET_GITHUB_PREFIX + accountHash + '.json'
  ), {
    method: 'put',
    headers: githubHeaders(token),
    contentType: 'application/json',
    payload: JSON.stringify(payload),
    muteHttpExceptions: true,
  });
  const status = response.getResponseCode();
  if (status !== 200 && status !== 201) {
    throw new Error('GitHub 아스트 저장을 확인하지 못했습니다. 새로고침 후 다시 시도해 주세요. (' + status + ')');
  }
}

function validateAstWallet(wallet, loginId) {
  if (!wallet || wallet.schemaVersion !== 1 || wallet.loginId !== loginId ||
      !Number.isSafeInteger(wallet.balance) || wallet.balance < 0 ||
      !Number.isSafeInteger(wallet.cycleStartedAt) || wallet.cycleStartedAt < 0 ||
      !Number.isSafeInteger(wallet.availableAt) ||
      wallet.availableAt - wallet.cycleStartedAt !== AST_INTERVAL_MS ||
      (wallet.lastClaimedAt !== null && wallet.lastClaimedAt !== wallet.cycleStartedAt) ||
      (wallet.lastRequestId !== null && typeof wallet.lastRequestId !== 'string')) {
    // Never silently reset corrupt or newer-version balances.
    throw new Error('저장된 아스트 정보 확인이 필요합니다. 관리자에게 문의해 주세요.');
  }
}

function validateGithub(token) {
  const response = UrlFetchApp.fetch(
    'https://api.github.com/repos/' + OWNER + '/' + REPOSITORY,
    {
      method: 'get',
      headers: githubHeaders(token),
      muteHttpExceptions: true,
    }
  );
  const status = response.getResponseCode();
  const body = JSON.parse(response.getContentText() || '{}');
  return jsonResponse({
    ok: status === 200,
    status: status,
    push: body.permissions && body.permissions.push === true,
  });
}

function saveJsonFile(token, request) {
  const path = String(request.path || '');
  if (!ALLOWED_JSON_PATHS.includes(path)) {
    return jsonResponse({ ok: false, error: '허용되지 않은 파일입니다.' });
  }
  if (request.content === undefined) {
    return jsonResponse({ ok: false, error: '저장할 내용이 없습니다.' });
  }

  const content =
    typeof request.content === 'string'
      ? request.content
      : JSON.stringify(request.content, null, 2);
  if (content.length > 1000000) {
    return jsonResponse({ ok: false, error: '데이터가 너무 큽니다.' });
  }

  const apiUrl = contentsUrl(path);
  const current = fetchCurrent(apiUrl, token);
  if (current.error) return current.error;

  const payload = {
    message: String(request.message || 'AST 앱 데이터 업데이트'),
    content: Utilities.base64Encode(content, Utilities.Charset.UTF_8),
    branch: BRANCH,
  };
  if (current.sha) payload.sha = current.sha;

  return putContent(apiUrl, token, payload, path);
}

function uploadFile(token, request) {
  const folder = String(request.folder || '');
  const fileName = String(request.fileName || '');
  const allowedExtensions = ALLOWED_UPLOADS[folder];
  if (!allowedExtensions || !isSafeFileName(fileName)) {
    return jsonResponse({ ok: false, error: '허용되지 않은 업로드 경로입니다.' });
  }

  const extension = fileName.split('.').pop().toLowerCase();
  if (!allowedExtensions.includes(extension)) {
    return jsonResponse({ ok: false, error: '허용되지 않은 파일 형식입니다.' });
  }

  const contentBase64 = String(request.contentBase64 || '');
  const maxBase64Length = folder === 'Image' ? 12000000 : 42000000;
  if (!contentBase64 || contentBase64.length > maxBase64Length) {
    return jsonResponse({ ok: false, error: '파일 크기 제한을 초과했습니다.' });
  }

  const path = folder + '/' + fileName;
  const apiUrl = contentsUrl(path);
  const current = fetchCurrent(apiUrl, token);
  if (current.error) return current.error;

  const payload = {
    message: String(request.message || 'AST 파일 업로드: ' + fileName),
    content: contentBase64,
    branch: BRANCH,
  };
  const sha = String(request.existingSha || current.sha || '');
  if (sha) payload.sha = sha;

  return putContent(apiUrl, token, payload, path);
}

function deleteFile(token, request) {
  const path = String(request.path || '');
  const parts = path.split('/');
  if (
    parts.length !== 2 ||
    !ALLOWED_UPLOADS[parts[0]] ||
    !isSafeFileName(parts[1])
  ) {
    return jsonResponse({ ok: false, error: '허용되지 않은 삭제 경로입니다.' });
  }

  const sha = String(request.sha || '');
  if (!sha) return jsonResponse({ ok: false, error: '파일 식별 정보가 없습니다.' });

  const response = UrlFetchApp.fetch(contentsUrl(path), {
    method: 'delete',
    headers: githubHeaders(token),
    contentType: 'application/json',
    payload: JSON.stringify({
      message: String(request.message || 'AST 파일 삭제: ' + parts[1]),
      sha: sha,
      branch: BRANCH,
    }),
    muteHttpExceptions: true,
  });
  const status = response.getResponseCode();
  if (status !== 200) return githubError(response, '파일을 삭제하지 못했습니다.');
  return jsonResponse({ ok: true, path: path });
}

function fetchCurrent(apiUrl, token) {
  const response = UrlFetchApp.fetch(
    apiUrl + '?ref=' + encodeURIComponent(BRANCH),
    { method: 'get', headers: githubHeaders(token), muteHttpExceptions: true }
  );
  const status = response.getResponseCode();
  if (status === 404) return { sha: null };
  if (status !== 200) {
    return { error: githubError(response, '현재 파일을 확인하지 못했습니다.') };
  }
  return { sha: JSON.parse(response.getContentText()).sha };
}

function putContent(apiUrl, token, payload, path) {
  const response = UrlFetchApp.fetch(apiUrl, {
    method: 'put',
    headers: githubHeaders(token),
    contentType: 'application/json',
    payload: JSON.stringify(payload),
    muteHttpExceptions: true,
  });
  const status = response.getResponseCode();
  if (status !== 200 && status !== 201) {
    return githubError(response, 'GitHub 저장에 실패했습니다.');
  }
  const body = JSON.parse(response.getContentText() || '{}');
  return jsonResponse({
    ok: true,
    path: path,
    downloadUrl: body.content && body.content.download_url,
  });
}

function githubError(response, fallback) {
  const status = response.getResponseCode();
  let detail = '';
  try {
    detail = JSON.parse(response.getContentText()).message || '';
  } catch (_) {}
  return jsonResponse({ ok: false, error: fallback, status: status, detail: detail });
}

function contentsUrl(path) {
  return (
    'https://api.github.com/repos/' +
    OWNER + '/' + REPOSITORY + '/contents/' +
    path.split('/').map(encodeURIComponent).join('/')
  );
}

function githubHeaders(token) {
  return {
    Authorization: 'Bearer ' + token,
    Accept: 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
  };
}

function isSafeFileName(value) {
  return (
    value.length > 0 &&
    value.length <= 180 &&
    !value.includes('/') &&
    !value.includes('\\') &&
    !value.includes('..')
  );
}

function jsonResponse(value) {
  return ContentService
    .createTextOutput(JSON.stringify(value))
    .setMimeType(ContentService.MimeType.JSON);
}


// Add as HomeGame.gs in the SAME Apps Script project as the AST wallet.
const HOME_PATH = 'remote-data/games/ast-home/state.json';
const HOME_PENDING = 'AST_HOME_PENDING_V1';
const HOME_TYPES = {
  wardrobe: [50,1,2], table: [100,2,3], chair: [30,1,1], sofa: [150,1,3],
  plant: [40,1,1], bookshelf: [80,1,2], 'coffee-table': [60,2,3],
  'elegant-sofa':[180,2,4],piano:[250,2,3],microphone:[70,1,1],'music-stand':[40,1,1],
  'banquet-table':[300,4,8],'dining-chair':[50,1,1],fruit:[20,1,2],'tea-set':[25,1,2],bread:[15,1,1]
};
function homeRead(token) {
  const r=UrlFetchApp.fetch(contentsUrl(HOME_PATH)+'?ref='+encodeURIComponent(BRANCH),{headers:githubHeaders(token),muteHttpExceptions:true});
  if(r.getResponseCode()===404)return {sha:null,state:{schemaVersion:1,revision:0,items:[],receipts:[],contributions:{}}};
  if(r.getResponseCode()!==200)throw new Error('집 저장 정보를 불러오지 못했습니다.');
  const file=JSON.parse(r.getContentText());
  const state=JSON.parse(Utilities.newBlob(Utilities.base64Decode(file.content.replace(/\s/g,''))).getDataAsString('UTF-8'));
  if(state.schemaVersion!==1||!Number.isSafeInteger(state.revision)||!Array.isArray(state.items)||!Array.isArray(state.receipts))throw new Error('집 데이터 형식을 확인해 주세요.');
  return {sha:file.sha,state:state};
}
// Recover Git-commit-before-wallet-write interruption under the same ScriptLock.
function homeRecover(properties,token) {
  const raw=properties.getProperty(HOME_PENDING);if(!raw)return;
  const pending=JSON.parse(raw),current=homeRead(token);
  if(current.state.receipts.some(r=>r.requestId===pending.requestId)) {
    const stored=readAstGithubWallet(token,pending.accountHash,pending.wallet.loginId);
    if(!stored.wallet)throw new Error('구매 복구용 GitHub 지갑이 없습니다.');
    if(JSON.stringify(stored.wallet)!==JSON.stringify(pending.wallet)){
      if(stored.sha!==pending.walletSha)throw new Error('구매 복구 중 지갑 버전이 변경되었습니다. 관리자 확인이 필요합니다.');
      saveAstGithubWallet(token,pending.accountHash,pending.wallet,stored.sha);
    }
  }
  properties.deleteProperty(HOME_PENDING);
}
function homeResponse(properties,token,loginId,state,status) {
  const wallet=readAstGithubWallet(token,astAccountHash(loginId),loginId).wallet;
  if(!wallet)throw new Error('홈 화면에서 아스트를 먼저 조회해 주세요.');
  return jsonResponse({ok:true,status:status,balance:wallet?wallet.balance:0,home:{schemaVersion:1,revision:state.revision,items:state.items,contributions:state.contributions||{},features:{mansion:1}}});
}
function homeRequest(properties,token,request) {
  const loginId=String(request.loginId||'').trim().toLowerCase();
  if(!loginId||loginId.length>128||/[\x00-\x1f\x7f]/.test(loginId))throw new Error('로그인이 필요합니다.');
  homeRecover(properties,token);
  const current=homeRead(token),state=current.state;
  if(request.action==='astHomeGet')return homeResponse(properties,token,loginId,state,'synced');
  if(typeof request.requestId!=='string'||!/^[a-zA-Z0-9_-]{16,80}$/.test(request.requestId))throw new Error('구매 요청 ID가 올바르지 않습니다.');
  const prior=state.receipts.find(r=>r.requestId===request.requestId);
  if(prior){if(prior.loginId!==loginId)throw new Error('요청 계정 불일치');return homeResponse(properties,token,loginId,state,'already_applied');}
  if(request.expectedRevision!==state.revision)return homeResponse(properties,token,loginId,state,'conflict');
  const i=request.item;
  if(!i||!Object.prototype.hasOwnProperty.call(HOME_TYPES,i.type)||typeof i.uid!=='string'||!/^[a-zA-Z0-9_-]{16,80}$/.test(i.uid)||![i.x,i.y,i.rotation].every(Number.isInteger)||i.rotation<0||i.rotation>3)throw new Error('가구 정보가 올바르지 않습니다.');
  const purchase=request.operation==='purchase';
  if(!purchase&&request.operation!=='move')throw new Error('지원하지 않는 작업입니다.');
  const old=state.items.find(o=>o.uid===i.uid);
  if((purchase&&old)||(!purchase&&(!old||old.type!==i.type)))return homeResponse(properties,token,loginId,state,'conflict');
  const dims=HOME_TYPES[i.type],w=i.rotation%2?dims[2]:dims[1],h=i.rotation%2?dims[1]:dims[2];
  if(i.area){if(!canBuild(i,state.items))return homeResponse(properties,token,loginId,state,'conflict');}
  else {
    if(!['wardrobe','table','chair','sofa','plant','bookshelf','coffee-table'].includes(i.type)||i.parent)throw new Error('이 가구는 실내 전용입니다.');
    if(i.x<0||i.y<0||i.x+w>12||i.y+h>14)throw new Error('배치 가능한 영역 밖입니다.');
    for(const o of state.items){if(o.area||o.uid===i.uid)continue;const d=HOME_TYPES[o.type],ow=o.rotation%2?d[2]:d[1],oh=o.rotation%2?d[1]:d[2];if(i.x+w>o.x&&o.x+ow>i.x&&i.y+h>o.y&&o.y+oh>i.y)return homeResponse(properties,token,loginId,state,'conflict');}
  }
  const accountHash=astAccountHash(loginId),storedWallet=readAstGithubWallet(token,accountHash,loginId);
  if(!storedWallet.wallet)throw new Error('홈 화면에서 아스트 잔액을 먼저 조회해 주세요.');
  const wallet=storedWallet.wallet;
  if(purchase&&wallet.balance<dims[0])return homeResponse(properties,token,loginId,state,'insufficient');
  if(state.items.length>=1000&&purchase)throw new Error('가구 수 제한에 도달했습니다.');
  if(purchase)wallet.balance-=dims[0];
  const item={uid:i.uid,type:i.type,x:i.x,y:i.y,rotation:i.rotation,placedBy:old?old.placedBy:loginId,purchasedAt:old?old.purchasedAt:Date.now(),purchasedPrice:old?old.purchasedPrice:dims[0]};
  if(i.area)item.area=i.area;if(i.parent)item.parent=i.parent;
  state.items=purchase?state.items.concat([item]):state.items.map(o=>o.uid===item.uid?item:o);
  if(purchase){state.contributions=state.contributions||{};state.contributions[loginId]=(state.contributions[loginId]||0)+dims[0];}
  state.revision++;state.receipts.push({requestId:request.requestId,loginId:loginId});state.receipts=state.receipts.slice(-512);
  properties.setProperty(HOME_PENDING,JSON.stringify({requestId:request.requestId,accountHash:accountHash,walletSha:storedWallet.sha,wallet:wallet}));
  const payload={message:'AST 집 꾸미기 '+state.revision,branch:BRANCH,content:Utilities.base64Encode(JSON.stringify(state),Utilities.Charset.UTF_8)};if(current.sha)payload.sha=current.sha;
  const r=UrlFetchApp.fetch(contentsUrl(HOME_PATH),{method:'put',headers:githubHeaders(token),contentType:'application/json',payload:JSON.stringify(payload),muteHttpExceptions:true});
  if(r.getResponseCode()!==200&&r.getResponseCode()!==201){homeRecover(properties,token);throw new Error('집 저장에 실패했습니다. 같은 요청으로 다시 시도해 주세요.');}
  homeRecover(properties,token);
  return homeResponse(properties,token,loginId,state,'applied');
}

// Expansion geometry and placement rules; generated from house-layout.mjs.
// This logical square grid is the single source of truth for rendering and rules.
const WORLD={width:2048,height:1536,cols:24,rows:30,origin:{x:1000,y:210},tileX:30,tileY:15};
const AREAS={
 hall:{name:'1층 거실',floor:1,x:9,y:0,w:15,h:30,kind:'living'},
 roomA:{name:'A룸 · 연습실',floor:1,x:0,y:0,w:8,h:9,kind:'practice'},
 roomB:{name:'B룸 · 연습실',floor:1,x:0,y:10,w:8,h:9,kind:'practice'},
 roomC:{name:'C룸 · 연습실',floor:1,x:0,y:20,w:8,h:10,kind:'practice'},
 dining:{name:'2층 다이닝 홀',floor:2,x:0,y:0,w:24,h:30,kind:'dining'}
};
const STAIR={x:20,y:23,w:4,h:7};
function project(x,y,floor=1){return {x:1000+(y-x)*30,y:(floor===1?210:410)+(x+y)*15}}
function unproject(p,floor=1){const dy=p.y-(floor===1?210:410);return {x:dy/30-(p.x-1000)/60,y:dy/30+(p.x-1000)/60}}
const HOUSE_ITEMS=[
 {id:'elegant-sofa',name:'클래식 소파',price:180,w:2,h:4,places:['living'],asset:'elegant-sofa',category:'가구'},
 {id:'coffee-table',name:'낮은 커피 테이블',price:60,w:2,h:3,places:['living'],asset:'coffee-table',category:'가구'},
 {id:'plant',name:'실내 화분',price:40,w:1,h:1,places:['living','practice','dining'],asset:'plant',category:'장식'},
 {id:'bookshelf',name:'악보 책장',price:80,w:1,h:2,places:['living','practice'],asset:'bookshelf',category:'가구'},
 {id:'piano',name:'업라이트 피아노',price:250,w:2,h:3,places:['practice'],asset:'piano',category:'악기'},
 {id:'microphone',name:'마이크',price:70,w:1,h:1,places:['practice'],asset:'microphone',category:'연습 장비'},
 {id:'music-stand',name:'악보 거치대',price:40,w:1,h:1,places:['practice'],asset:'music-stand',category:'연습 장비'},
 {id:'chair',name:'연습 의자',price:30,w:1,h:1,places:['practice'],asset:'chair',category:'가구'},
 {id:'banquet-table',name:'대형 식탁',price:300,w:4,h:8,places:['dining'],asset:'banquet-table',category:'가구',surface:{w:4,h:8}},
 {id:'dining-chair',name:'다이닝 의자',price:50,w:1,h:1,places:['dining'],asset:'dining-chair',category:'가구'},
 {id:'fruit',name:'과일 플래터',price:20,w:1,h:2,places:['surface'],asset:'fruit',category:'음식'},
 {id:'tea-set',name:'티 세트',price:25,w:1,h:2,places:['surface'],asset:'tea-set',category:'음식'},
 {id:'bread',name:'빵 바구니',price:15,w:1,h:1,places:['surface'],asset:'bread',category:'음식'}
];
const definition=id=>HOUSE_ITEMS.find(i=>i.id===id);
function size(item){const d=definition(item.type);if(!d)throw new Error('Unknown furniture');return item.rotation%2?[d.h,d.w]:[d.w,d.h]}
function overlap(a,b,aw,ah,bw,bh){return a.x+aw>b.x&&b.x+bw>a.x&&a.y+ah>b.y&&b.y+bh>a.y}
function canBuild(item,items){
 const d=definition(item.type),area=AREAS[item.area];
 if(!d||!area||![item.x,item.y,item.rotation].every(Number.isInteger)||item.rotation<0||item.rotation>3)return false;
 let bounds={w:area.w,h:area.h},kind=area.kind;
 if(item.parent){const table=items.find(i=>i.uid===item.parent&&i.type==='banquet-table'&&i.area===item.area&&!i.parent);if(!table)return false;bounds=definition(table.type).surface;kind='surface'}
 if(!d.places.includes(kind))return false;
 const [w,h]=size(item);
 const margin=!item.parent&&area.kind==='practice'?1:0;
 if(item.x<margin||item.y<margin||item.x+w>bounds.w-margin||item.y+h>bounds.h-margin)return false;
 if(!item.parent){const global={x:area.x+item.x,y:area.y+item.y};if(overlap(global,STAIR,w,h,STAIR.w,STAIR.h))return false;}
 return items.filter(i=>i.uid!==item.uid&&i.area===item.area&&(i.parent||null)===(item.parent||null)).every(i=>{const [iw,ih]=size(i);return !overlap(item,i,w,h,iw,ih)});
}
function floorItems(items,floor){return items.filter(i=>AREAS[i.area]?.floor===floor)}
function furniturePoint(item,items){const area=AREAS[item.area];if(!item.parent)return {x:area.x+item.x,y:area.y+item.y};const table=items.find(i=>i.uid===item.parent);if(!table)return {x:0,y:0};const td=definition(table.type);let x=item.x,y=item.y;const [w,h]=size(item);if(table.rotation===1){[x,y]=[td.h-item.y-h,item.x]}else if(table.rotation===2){[x,y]=[td.w-item.x-w,td.h-item.y-h]}else if(table.rotation===3){[x,y]=[item.y,td.w-item.x-w]}return {x:area.x+table.x+x,y:area.y+table.y+y}}
function spriteBox(item,frame,items){const p=furniturePoint(item,items);let [w,h]=size(item);const table=item.parent?items.find(i=>i.uid===item.parent):null;if(table?.rotation%2)[w,h]=[h,w];const center=project(p.x+w/2,p.y+h/2,AREAS[item.area].floor),front=project(p.x+w,p.y+h,AREAS[item.area].floor);const width=(w+h)*30*.90,height=width*frame.h/frame.w;return {x:center.x-width/2,y:front.y-height-3-(item.parent?45:0),w:width,h:height}}
