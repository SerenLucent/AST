const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../build/web');
const prefix = '/AST/ast-web/';
const types = {'.html':'text/html; charset=utf-8','.js':'application/javascript','.mjs':'application/javascript','.json':'application/json','.wasm':'application/wasm','.png':'image/png','.webp':'image/webp','.css':'text/css','.ttf':'font/ttf','.otf':'font/otf'};
http.createServer((req,res) => {
  const url = new URL(req.url,'http://127.0.0.1');
  if(url.pathname==='/') {res.writeHead(302,{Location:prefix});return res.end()}
  if(!url.pathname.startsWith(prefix)){res.writeHead(404);return res.end()}
  let relative;try{relative=decodeURIComponent(url.pathname.slice(prefix.length))}catch{res.writeHead(400);return res.end()}
  const file=path.resolve(root,relative || 'index.html');
  if(!file.startsWith(root+path.sep)){res.writeHead(403);return res.end()}
  fs.readFile(file,(e,data)=>{
    if(e){res.writeHead(404);return res.end('Not found')}
    res.writeHead(200,{'Content-Type':types[path.extname(file)] || 'application/octet-stream','Cache-Control':'no-store'});res.end(data);
  });
}).listen(4174,'127.0.0.1',()=>console.log('AST web preview: http://127.0.0.1:4174'+prefix));
