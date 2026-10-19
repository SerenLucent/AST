// Local Chromium QA only. Native bridge, wallets and purchases are mocked;
// the browser may connect only to this loopback static server.
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const http = require('node:http');
const {chromium} = require('playwright');
const root = process.env.AST_HOME_ROOT || path.resolve(__dirname, '..');
const web = path.join(root, 'docs/games/ast-home');
const outputRoot = path.join(root, 'output/ast-home-performance');
const output = path.join(outputRoot, process.env.AST_TEST_MOBILE ? 'mobile' : 'desktop');
const before = process.env.AST_HOME_BASELINE || path.join(outputRoot, 'before');
const mime = {'.html':'text/html', '.js':'text/javascript', '.mjs':'text/javascript', '.css':'text/css', '.png':'image/png', '.webp':'image/webp'};

async function main() {
  await fs.mkdir(output, {recursive:true});
  const server = http.createServer(async (req, res) => {
    try {
      const pathname = new URL(req.url, 'http://localhost').pathname;
      const [, variant, ...rest] = pathname.split('/');
      if (!['before','after'].includes(variant)) {res.writeHead(404).end(); return;}
      const relative = rest.join('/') || 'index.html';
      const base = variant === 'before' && (process.env.AST_HOME_BASELINE || ['index.html','game.js','mansion.js'].includes(relative)) ? before : web;
      const file = path.resolve(base, relative);
      if (!file.startsWith(base + path.sep)) throw new Error('path outside assets');
      const data = await fs.readFile(file);
      res.writeHead(200, {'Content-Type':mime[path.extname(file)] || 'application/octet-stream', 'Content-Length':data.length, 'Cache-Control':'public, max-age=3600'});
      res.end(data);
    } catch {res.writeHead(404).end();}
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const origin = `http://127.0.0.1:${server.address().port}`;
  let browser;
  try {
    browser = await chromium.launch({headless:true, executablePath:process.env.AST_TEST_BROWSER || 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
    const report = {conditions:{downloadMbps:8, latencyMs:80, cpuSlowdown:4, mockServerMs:1200}, runs:[]};
    const variants = process.env.AST_TEST_AFTER_ONLY ? ['after'] : ['before','after'];
    const viewport = process.env.AST_TEST_MOBILE ? {width:412,height:915} : {width:1100,height:1000};
    report.conditions.viewport = viewport;
    for (const variant of variants) for (const scene of ['entry','mansion']) {
      const context = await browser.newContext({viewport, deviceScaleFactor:1});
      await context.route('**/*', route => route.request().url().startsWith(origin + '/') ? route.continue() : route.abort());
      await context.addInitScript(() => {
        window.__qa = {pixelScans:0, firstPaint:null, rpc:[], failRead:false, failWrites:false, balance:5000, revision:1, ids:[], items:[
          {uid:'entry-chair', type:'chair',x:4,y:5,rotation:0},
          {uid:'hall-sofa',type:'elegant-sofa',area:'hall',x:1,y:1,rotation:0},
          {uid:'room-piano',type:'piano',area:'roomA',x:2,y:2,rotation:0},
          {uid:'dining-table',type:'banquet-table',area:'dining',x:4,y:4,rotation:0},
        ]};
        const scan = CanvasRenderingContext2D.prototype.getImageData;
        CanvasRenderingContext2D.prototype.getImageData = function(...args){window.__qa.pixelScans++; return scan.apply(this,args)};
        const draw = CanvasRenderingContext2D.prototype.drawImage;
        CanvasRenderingContext2D.prototype.drawImage = function(...args){if(['game','houseCanvas'].includes(this.canvas.id)&&window.__qa.firstPaint===null)window.__qa.firstPaint=performance.now();return draw.apply(this,args)};
        window.AstHome = {postMessage(raw) {
          const {id,payload} = JSON.parse(raw), q = window.__qa;
          q.rpc.push({action:payload.action,at:performance.now()});
          setTimeout(() => {
            if(q.failRead && payload.action==='astHomeGet') {window.astHomeResponse({id,error:'QA offline'});return;}
            if(q.failWrites && payload.action==='astHomeApply') {window.astHomeResponse({id,error:'QA write offline'});return;}
            let status='synced';
            if(payload.action==='astHomeApply') {
              if(payload.accountKey!=='a'.repeat(64))throw new Error('Owner mismatch');
              status='already_applied';
              if(!q.ids.includes(payload.requestId)) {
                q.ids.push(payload.requestId);status='applied';q.revision++;
                if(payload.operation==='purchase') {q.balance-=30;q.items.push(payload.item);}
                else q.items=q.items.map(i=>i.uid===payload.item.uid?payload.item:i);
              }
            }
            window.astHomeResponse({id,result:{ok:true,status,accountKey:'a'.repeat(64),balance:q.balance,home:{revision:q.revision,items:q.items,features:{mansion:1,furniture:2}}}});
          },1200);
        }};
      });
      const page = await context.newPage(), errors = [];
      page.on('pageerror', e => errors.push(e.message));
      const cdp = await context.newCDPSession(page);
      await cdp.send('Network.enable');
      await cdp.send('Network.emulateNetworkConditions',{offline:false,latency:80,downloadThroughput:1000000,uploadThroughput:1000000});
      await cdp.send('Emulation.setCPUThrottlingRate',{rate:4});
      await page.goto(`${origin}/${variant}/?mode=shared${scene==='mansion'?'&scene=mansion':''}`,{waitUntil:'domcontentloaded'});
      await page.waitForFunction(scene => {
        const status=document.getElementById(scene==='mansion'?'houseStatus':'status')?.textContent;
        const initialized=scene==='mansion' || document.querySelectorAll('#catalog .card').length===7;
        return initialized && window.__qa.firstPaint!==null && status?.includes(scene==='mansion'?'공동 실내':'공동 거실');
      }, scene, {timeout:90000});
      const stats = await page.evaluate(() => ({readyMs:performance.now(),firstPaintMs:window.__qa.firstPaint,pixelScans:window.__qa.pixelScans,
        serverStartMs:window.__qa.rpc[0]?.at,images:performance.getEntriesByType('resource').filter(e=>/\.(png|webp)(\?|$)/.test(e.name)).map(e=>({path:new URL(e.name).pathname,bytes:e.encodedBodySize}))}));
      stats.imageBytes=stats.images.reduce((n,e)=>n+e.bytes,0);
      await page.screenshot({path:path.join(output,`${variant}-${scene}.png`),fullPage:true});
      if(variant==='after') {
        assert.equal(stats.pixelScans,0);
        assert.ok(stats.images.every(i=>!i.path.endsWith('.png')));
        assert.ok(stats.serverStartMs < stats.readyMs-900);
        if(scene==='mansion') {
          assert.ok(!stats.images.some(i=>/floor-2|fruit-|tea-set-|bread-/.test(i.path)));
          // A missing lazy asset must leave the old floor usable and retryable.
          const failedFloor = '**/assets/optimized/floor-2-*.webp';
          await page.route(failedFloor, route => route.abort());
          await page.click('#floorTwo');
          await page.waitForFunction(()=>document.getElementById('houseStatus').textContent.includes('층 버튼을 눌러 다시 시도'));
          assert.equal(await page.locator('#floorOne').getAttribute('aria-pressed'),'true');
          await page.unroute(failedFloor);
          await page.click('#floorTwo');
          await page.waitForFunction(()=>document.getElementById('floorTwo').getAttribute('aria-pressed')==='true');
          await page.waitForFunction(()=>!document.getElementById('houseSync').disabled);
          await page.click('[data-area="dining"]');
          await page.click('#houseShop');
          await page.waitForFunction(()=>!document.querySelector('#houseCards [data-type="dining-chair"]').disabled);
          await page.screenshot({path:path.join(output,'after-dining-store.png'),fullPage:true});
          await page.click('#houseStoreClose');
          await page.click('#floorOne');
          await page.waitForFunction(()=>document.getElementById('floorOne').getAttribute('aria-pressed')==='true');
          await page.click('[data-area="roomA"]');
          await page.click('#houseShop');
          await page.waitForFunction(()=>!document.querySelector('#houseCards [data-type="chair"]').disabled);
          await page.click('#houseCards [data-type="chair"]');
          await page.click('#draftConfirm');
          await page.waitForFunction(()=>document.getElementById('houseWallet').textContent==='4,970 아스트');
          assert.equal(await page.evaluate(()=>window.__qa.items.filter(i=>i.type==='chair').length),2);
          await page.evaluate(()=>{window.__qa.failRead=true});
          await page.click('#houseSync');
          await page.waitForFunction(()=>document.getElementById('houseStatus').textContent.includes('QA offline'));
          assert.equal(await page.locator('#houseShop').isDisabled(),true);
          await page.evaluate(()=>{window.__qa.failRead=false});
          await page.click('#houseSync');
          await page.waitForFunction(()=>document.getElementById('houseWallet').textContent==='4,970 아스트');
        } else {
          await page.click('#shopButton');
          await page.waitForFunction(()=>!document.querySelector('#catalog [data-type="chair"]').disabled);
          await page.click('#catalog [data-type="chair"]');
          // Default placement overlaps the fixture chair, so move it first.
          await page.click('#rotateDraft');
          await page.click('#cancel');
          assert.equal(await page.evaluate(()=>window.__qa.balance),5000);
        }
      }
      assert.deepEqual(errors,[], `${variant}/${scene} browser errors`);
      report.runs.push({variant,scene,...stats});
      console.log(JSON.stringify({variant,scene,readyMs:stats.readyMs,firstPaintMs:stats.firstPaintMs,imageBytes:stats.imageBytes,pixelScans:stats.pixelScans}));
      await context.close();
    }
    await fs.writeFile(path.join(output,'browser-report.json'),JSON.stringify(report,null,2));
  } finally {
    if(browser)await browser.close();
    await new Promise(resolve=>server.close(resolve));
  }
}
main().catch(e=>{console.error(e);process.exitCode=1});
