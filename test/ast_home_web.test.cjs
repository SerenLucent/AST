// Exercise the actual browser entry point + bridge + account session without
// any network, real purchases, or changes to user wallets.
const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');
const {pathToFileURL} = require('node:url');
const root = process.env.AST_HOME_ROOT || path.resolve(__dirname, '..');
const webRoot = path.join(root, 'docs/games/ast-home');
const accountKey = crypto.createHash('sha256').update('web-test-account').digest('hex');
const pendingKey = 'ast-home-pending-v2:' + accountKey;
const copy = value => JSON.parse(JSON.stringify(value));

async function page({balance = 80, legacy = false, failRead = false, failImage = false, shared = true} = {}) {
  const {SharedHomeSession} = await import(pathToFileURL(path.join(webRoot, 'shared-session.mjs')));
  const model = await import(pathToFileURL(path.join(webRoot, 'model.mjs')));
  const {ASSETS} = await import(pathToFileURL(path.join(webRoot, 'asset-manifest.mjs')));
  const geometry = await import(pathToFileURL(path.join(webRoot, 'sprite-geometry.mjs')));
  const records = new Map(), calls = [], timers = new Map();
  if (legacy) records.set('ast-home-pending-v1', JSON.stringify({
    action: 'astHomeApply', operation: 'purchase', requestId: 'unowned-request-0001',
    expectedRevision: 0, item: {uid: 'unowned-chair-0001', type: 'chair', x: 4, y: 5, rotation: 0},
  }));
  const server = {balance, revision: 0, items: [], ids: new Set(), failRead, loseReplies: false};
  const elements = new Map();
  function element(tag) {
    const e = {tag, children: [], dataset: {}, style: {}, hidden: false, disabled: false, textContent: '', open: false,
      append(...children) { this.children.push(...children); },
      setAttribute() {}, addEventListener() {}, closest() { return this; },
      showModal() { this.open = true; }, close() { this.open = false; },
      querySelectorAll() { return this.children.filter(c => c.className === 'card'); },
      classList: {toggle() {}, add() {}, remove() {}},
    };
    const drawing = {drawn: [],
      drawImage(im) { this.drawn.push(im.src); }, clearRect() { this.drawn = []; },
      getImageData() { throw new Error('Runtime pixel scans must not return'); },
      beginPath() {}, moveTo() {}, lineTo() {}, closePath() {}, fill() {}, stroke() {},
      save() {}, restore() {}, translate() {}, scale() {}, transform() {}, clip() {},
    };
    e.getContext = () => drawing;
    return e;
  }
  const document = {
    getElementById(id) { if (!elements.has(id)) elements.set(id, element(id)); return elements.get(id); },
    createElement: element, createTextNode: text => ({textContent: text}),
  };
  class MockImage {
    width = 4; height = 4;
    set src(value) { this._src = value; queueMicrotask(() => this.onload?.()); }
    get src() { return this._src; }
    async decode() { if (failImage) throw new Error('image unavailable'); }
  }
  function snapshot(status = 'synced') {
    return {ok: true, status, accountKey, balance: server.balance,
      home: {revision: server.revision, items: copy(server.items)}, memberNames: {}};
  }
  async function nativeRequest(payload) {
    calls.push(copy(payload));
    if (payload.action === 'astHomeGet') {
      if (server.failRead) throw new Error('네트워크 연결 실패');
      return snapshot();
    }
    // Same guard as the installed AST 3.1.0 native bridge.
    if (payload.accountKey !== accountKey) throw new Error('구매 계정이 다릅니다.');
    assert.equal(payload.action, 'astHomeApply');
    let status = 'already_applied';
    if (!server.ids.has(payload.requestId)) {
      assert.equal(payload.expectedRevision, server.revision);
      assert.equal(payload.operation, 'purchase');
      assert.equal(payload.item.type, 'chair');
      server.balance -= 30; server.items.push(copy(payload.item)); server.revision++;
      server.ids.add(payload.requestId); status = 'applied';
    }
    if (server.loseReplies) throw new Error('응답 유실');
    return snapshot(status);
  }
  const host = {AstHome: {postMessage(raw) {
    const {id, payload} = JSON.parse(raw);
    nativeRequest(payload).then(
      result => host.astHomeResponse({id, result}),
      error => host.astHomeResponse({id, error: error.message}),
    );
  }}};
  const context = vm.createContext({
    ...model, ...geometry, ASSETS, SharedHomeSession, document, Image: MockImage, window: host,
    mountPetCare: () => ({bonus: 0, accept() {}}),
    location: {search: shared ? '?mode=shared' : '', reload() {}}, URLSearchParams, crypto,
    localStorage: {getItem: k => records.get(k) ?? null, setItem: (k, v) => records.set(k, v), removeItem: k => records.delete(k)},
    setTimeout(fn, delay) { const id = timers.size + 1; timers.set(id, {fn, delay}); return id; },
    clearTimeout(id) { timers.delete(id); }, console: {error() {}},
  });
  const bridge = fs.readFileSync(path.join(webRoot, 'ast-bridge.js'), 'utf8').replace('export function', 'function');
  vm.runInContext(bridge + '\nglobalThis.astRequest=request;', context);
  const loader = fs.readFileSync(path.join(webRoot, 'asset-loader.mjs'), 'utf8')
    .replace(/^import .*;\r?\n/gm, '').replaceAll('export function', 'function');
  vm.runInContext('(function(){' + loader + '\nObject.assign(globalThis,{loadAsset,assetUrl,spriteFrames});})()', context);
  const game = fs.readFileSync(path.join(webRoot, 'game.js'), 'utf8')
    .replace(/^import .*;\r?\n/gm, '')
    .replace(/^start\(\);/m, 'globalThis.started=start();');
  vm.runInContext(game, context);
  await context.started;
  const $ = id => document.getElementById(id);
  return {server, calls, records, $, timers,
    cards: () => $('catalog').children,
    async buyChair() { this.cards().find(c => c.dataset.type === 'chair').onclick(); await $('confirm').onclick(); },
  };
}

test('installed 3.1.0 reopens with an old failed chair request: load 80 AST, never replay v1', async () => {
  const p = await page({legacy: true});
  assert.equal(p.$('wallet').textContent, '80 아스트');
  assert.deepEqual(p.calls.map(c => c.action), ['astHomeGet']);
  assert.ok(p.records.has('ast-home-pending-v1'));
  assert.equal(p.$('retrySync').hidden, true);
  assert.doesNotMatch(p.$('status').textContent, /이미지|HTTP/);
  assert.equal(p.cards().find(c => c.dataset.type === 'chair').disabled, false);
});

test('actual game purchase includes the native account key and shows the saved chair + 50 AST', async () => {
  const p = await page({legacy: true});
  await p.buyChair();
  const writes = p.calls.filter(c => c.action === 'astHomeApply');
  assert.equal(writes.length, 1);
  assert.equal(writes[0].accountKey, accountKey);
  assert.equal(p.server.balance, 50);
  assert.equal(p.server.items.length, 1);
  assert.equal(p.$('wallet').textContent, '50 아스트');
  assert.ok(p.$('game').getContext().drawn.some(url => /chair-4dir-.*\.webp$/.test(url)));
  assert.equal(p.records.has(pendingKey), false);
  assert.ok(p.records.has('ast-home-pending-v1'));
  assert.equal(p.timers.size, 0);
});

test('failed server read is not 0 AST or an image/HTTP-server error; retry restores the balance', async () => {
  const p = await page({failRead: true});
  assert.equal(p.$('wallet').textContent, '잔액 조회 필요');
  assert.match(p.$('status').textContent, /네트워크 연결 실패/);
  assert.doesNotMatch(p.$('status').textContent, /이미지|HTTP/);
  assert.ok(p.cards().every(c => c.disabled));
  assert.equal(p.$('retrySync').hidden, false);
  p.server.failRead = false;
  await p.$('retrySync').onclick();
  assert.equal(p.$('wallet').textContent, '80 아스트');
  assert.equal(p.$('retrySync').hidden, true);
});

test('lost purchase reply blocks new spending; retry first refreshes and then deduplicates the old request', async () => {
  const p = await page();
  p.server.loseReplies = true;
  await p.buyChair();
  assert.equal(p.server.balance, 50);
  assert.equal(p.$('wallet').textContent, '80 아스트 · 확인 필요');
  assert.ok(p.cards().every(c => c.disabled));
  assert.equal(p.$('confirm').disabled, true);
  assert.equal(p.$('retrySync').hidden, false);
  assert.ok(p.records.has(pendingKey));
  p.server.loseReplies = false;
  const before = p.calls.length;
  await p.$('retrySync').onclick();
  assert.equal(p.calls[before].action, 'astHomeGet');
  assert.equal(p.$('wallet').textContent, '50 아스트');
  assert.equal(p.server.items.length, 1);
  assert.equal(new Set(p.calls.filter(c => c.action === 'astHomeApply').map(c => c.requestId)).size, 1);
  assert.equal(p.records.has(pendingKey), false);
});

test('actual zero server balance is shown as zero and cannot buy furniture', async () => {
  const p = await page({balance: 0});
  assert.equal(p.$('wallet').textContent, '0 아스트');
  assert.ok(p.cards().every(c => c.disabled));
  assert.equal(p.$('retrySync').hidden, true);
});

test('actual image failure shows an image retry, not local HTTP server instructions', async () => {
  const p = await page({failImage: true});
  assert.match(p.$('status').textContent, /이미지를 불러오지 못했습니다/);
  assert.doesNotMatch(p.$('status').textContent, /HTTP/);
  assert.equal(p.$('retrySync').textContent, '다시 불러오기');
  assert.equal(p.$('retrySync').hidden, false);
  // Read-only refresh starts in parallel, even if image decoding then fails.
  assert.deepEqual(p.calls.map(c => c.action), ['astHomeGet']);
});

test('standalone prototype keeps its local balance and never touches the server', async () => {
  const p = await page({shared: false});
  assert.equal(p.$('wallet').textContent, '5,000 아스트');
  await p.buyChair();
  assert.equal(p.$('wallet').textContent, '4,970 아스트');
  assert.ok(p.records.has('myhome-prototype-v1'));
  assert.equal(p.calls.length, 0);
  assert.equal(p.server.balance, 80);
});

test('HTML cache version loads a real game entry point which imports the required session module', () => {
  const html = fs.readFileSync(path.join(webRoot, 'index.html'), 'utf8');
  assert.match(html, /game\.js\?v=20261022-pets1/);
  assert.match(html, /id="retrySync"/);
  const game = fs.readFileSync(path.join(webRoot, 'game.js'), 'utf8');
  assert.match(game, /new SharedHomeSession/);
  for (const [, dependency] of game.matchAll(/from '\.\/([^'?]+)(?:\?[^']*)?'/g)) {
    assert.ok(fs.existsSync(path.join(webRoot, dependency)), dependency);
  }
  const bridge = fs.readFileSync(path.join(webRoot, 'ast-bridge.js'), 'utf8');
  assert.match(bridge, /120000/);
});

test('camera buttons zoom to 300 percent, clamp, and reset to 100 percent',async()=>{const p=await page({shared:false});for(let i=0;i<12;i++)p.$('zoomIn').onclick();assert.equal(p.$('zoomReset').textContent,'300%');assert.equal(p.$('zoomIn').disabled,true);p.$('zoomOut').onclick();assert.equal(p.$('zoomReset').textContent,'275%');p.$('zoomReset').onclick();assert.equal(p.$('zoomReset').textContent,'100%');assert.equal(p.$('zoomOut').disabled,true);});

