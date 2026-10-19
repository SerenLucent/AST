const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const vm = require('node:vm');
const {pathToFileURL} = require('node:url');
const web = path.resolve(process.env.AST_HOME_ROOT || path.resolve(__dirname, '..'), 'docs/games/ast-home');
const manifest = () => import(pathToFileURL(path.join(web, 'asset-manifest.mjs')));

test('all optimized assets exist, retain original PNGs, and fit the byte budget', async () => {
  const {ASSETS} = await manifest();
  let before = 0, after = 0;
  assert.ok(Object.keys(ASSETS).length >= 20);
  for (const [source, asset] of Object.entries(ASSETS)) {
    const original = fs.readFileSync(path.join(web, source));
    assert.equal(crypto.createHash('sha256').update(original).digest('hex'), asset.originalSha256);
    const encoded = fs.readFileSync(path.join(web, asset.url));
    assert.equal(encoded.subarray(8, 12).toString(), 'WEBP');
    assert.equal(encoded.length, asset.bytes);
    assert.match(asset.url, new RegExp(crypto.createHash('sha256').update(encoded).digest('hex').slice(0, 12)));
    assert.ok(asset.bytes < original.length, source);
    for (const threshold of [30, 40]) if (asset['frames' + threshold]) {
      assert.equal(asset['frames' + threshold].length, 4);
      for (const f of asset['frames' + threshold]) {
        assert.ok(f.x >= 0 && f.y >= 0 && f.w > 0 && f.h > 0);
        assert.ok(f.x + f.w <= asset.width && f.y + f.h <= asset.height);
      }
    }
    before += original.length; after += asset.bytes;
  }
  assert.ok(after < before * .15, `${before} -> ${after}`);
  const coin = ASSETS['assets/ui/ast-coin.png'];
  assert.ok(coin.width <= 96 && coin.bytes < 10000);
  assert.deepEqual(fs.readFileSync(path.join(web, coin.url)), fs.readFileSync(path.join(web, 'assets/optimized/ast-coin-small-v1.webp')));
});

test('renderers use precomputed bounds, not synchronous pixel scans', () => {
  for (const file of ['game.js', 'mansion.js']) {
    const code = fs.readFileSync(path.join(web, file), 'utf8');
    assert.doesNotMatch(code, /getImageData/);
    assert.match(code, /spriteFrames/);
  }
});

test('published furniture registration stays exactly equal to the original alpha scan', async () => {
  const geometry = path.join(web, 'sprite-geometry.mjs');
  if (!fs.existsSync(geometry)) return;
  const sharp = require('sharp');
  const {scanAtlas} = await import(pathToFileURL(geometry));
  const {ASSETS} = await manifest();
  let checked = 0;
  for (const [source, asset] of Object.entries(ASSETS)) {
    if (!source.endsWith('-4dir.png')) continue;
    const {data, info} = await sharp(path.join(web, source)).ensureAlpha().raw().toBuffer({resolveWithObject:true});
    assert.deepEqual(asset.framesRegistered, scanAtlas(data,info.width,info.height), source);
    checked++;
  }
  assert.equal(checked,25); // All 100 directions, including terrace furniture.
});

test('image loader deduplicates in-flight work, evicts failures, and retries', async () => {
  const {ASSETS} = await manifest();
  let count = 0, fail = true;
  class Image {
    set src(url) { this.url = url; count++; queueMicrotask(() => fail ? this.onerror() : this.onload()); }
    async decode() {}
  }
  const context = vm.createContext({ASSETS, Image});
  const code = fs.readFileSync(path.join(web, 'asset-loader.mjs'), 'utf8')
    .replace(/^import .*;\r?\n/gm, '').replaceAll('export function', 'function');
  vm.runInContext(code, context);
  const source = 'assets/furniture/chair-4dir.png';
  const first = context.loadAsset(source);
  assert.equal(context.loadAsset(source), first);
  await assert.rejects(first, /이미지/);
  fail = false;
  const image = await context.loadAsset(source);
  assert.match(image.url, /\.webp$/);
  assert.equal(await context.loadAsset(source), image);
  assert.equal(count, 2);
});
