// Check the actual deployable bundle. Never print any configured secret value.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const project = path.resolve(__dirname, '..');
const build = path.join(project, 'build/web');
function files(dir) {return fs.readdirSync(dir,{withFileTypes:true}).flatMap(e=>e.isDirectory()?files(path.join(dir,e.name)):[path.join(dir,e.name)])}
const config = JSON.parse(fs.readFileSync(path.join(build,'web-config.json'),'utf8'));
assert.match(config.apiUrl,/^https:\/\/script\.google\.com\/macros\/s\/[A-Za-z0-9_-]+\/exec$/);
assert.ok(fs.readFileSync(path.join(build,'index.html'),'utf8').includes('<base href="/AST/ast-web/">'));
for (const asset of ['main.dart.js','manifest.json','icons/apple-touch-icon.png',
  'assets/packages/nwc_player_lab/assets/soundfonts/piano.sf2',
  'assets/packages/flutter_soloud/web/libflutter_soloud_plugin.wasm',
  'assets/packages/flutter_soloud/web/init_module.dart.js']) assert.ok(fs.statSync(path.join(build,asset)).size>0,asset);
const secrets=[];
for (const name of ['apps_script_config.json','game_score_defines.json','private_config.json']) {
  const p=path.resolve(project,'../config',name);
  if(fs.existsSync(p)) for(const [key,value] of Object.entries(JSON.parse(fs.readFileSync(p,'utf8')))) {
    if(/key|token|password|secret/i.test(key) && typeof value==='string' && value.length>=8) secrets.push(value);
  }
}
const publicFiles=files(build);
const sourceFiles=files(project).filter(f=>!/[\\/](?:build|verification|\.dart_tool|\.git)[\\/]/.test(f));
for (const file of [...publicFiles,...sourceFiles]) {
  assert.ok(!/(?:private_config|apps_script_config|game_score_defines|main\.json)$/i.test(file),'Forbidden config asset');
  if(/\.(js|cjs|gs|dart|json|html|txt|map|yaml|ps1)$/.test(file)) {
    const text=fs.readFileSync(file,'utf8');
    for(const secret of secrets) assert.ok(!text.includes(secret),'Private key leaked into '+path.relative(build,file));
  }
}
console.log('PASS: base path, runtime/audio assets, API URL and private-key exclusion ('+publicFiles.length+' public files and '+sourceFiles.length+' source files).');
