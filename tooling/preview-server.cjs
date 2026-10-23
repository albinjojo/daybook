const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(process.argv[2]);
const port = Number(process.argv[3] || 4174);
const types = {'.html':'text/html','.js':'text/javascript','.json':'application/json','.css':'text/css','.wasm':'application/wasm','.png':'image/png','.ttf':'font/ttf'};
http.createServer((req,res)=>{
  let pathname;try{pathname=decodeURIComponent(new URL(req.url,'http://localhost').pathname);}catch{res.writeHead(400).end();return;}
  const target=path.resolve(root,'.'+pathname);
  if(target!==root&&!target.startsWith(root+path.sep)){res.writeHead(403).end();return;}
  const file=target===root?path.join(root,'index.html'):target;
  fs.readFile(file,(error,data)=>{if(error){res.writeHead(404).end();return;}res.writeHead(200,{'Content-Type':types[path.extname(file)]||'application/octet-stream','Cache-Control':'no-store'});res.end(data);});
}).listen(port,'127.0.0.1',()=>console.log(`Daybook preview http://localhost:${port}`));
