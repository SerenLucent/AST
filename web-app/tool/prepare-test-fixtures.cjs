const fs = require('node:fs');
const path = require('node:path');
const zlib = require('node:zlib');
const project = path.resolve(__dirname, '..');
const out = path.join(project, 'verification');
fs.mkdirSync(out,{recursive:true});
const score = fs.readFileSync(path.join(project,'test/fixtures/ast-practice.nwctxt'));
fs.writeFileSync(path.join(out,'ast-practice.nwc'),Buffer.concat([Buffer.from('[NWZ]\0','ascii'),zlib.deflateSync(score)]));
console.log('Generated owned 8-measure NWC browser-test fixture.');
