// Local preview only. No dependencies or build tools required.
import {createServer} from 'node:http';
import {createReadStream} from 'node:fs';
import {stat} from 'node:fs/promises';
import {resolve, extname, sep} from 'node:path';
import {fileURLToPath} from 'node:url';
const root = fileURLToPath(new URL('../Website/dist/', import.meta.url));
const types = {'.html':'text/html; charset=utf-8','.css':'text/css; charset=utf-8','.js':'text/javascript; charset=utf-8','.png':'image/png','.zip':'application/zip','.txt':'text/plain; charset=utf-8','.sha256':'text/plain; charset=utf-8','.xml':'application/xml'};
const port = Number(process.env.PORT || 4173);
createServer(async (request,response) => {
  try {
    const pathname = decodeURIComponent(new URL(request.url,'http://localhost').pathname);
    const path = resolve(root, '.' + (pathname.endsWith('/') ? pathname+'index.html' : pathname));
    if (!path.startsWith(resolve(root)+sep)) { response.writeHead(403).end(); return; }
    const info = await stat(path);
    if (!info.isFile()) throw new Error('not a file');
    response.writeHead(200,{'Content-Type':types[extname(path)] || 'application/octet-stream','Content-Length':info.size});
    if(request.method === 'HEAD') response.end(); else createReadStream(path).pipe(response);
  } catch {response.writeHead(404,{'Content-Type':'text/plain'}).end('Not found');}
}).listen(port,'127.0.0.1',()=>console.log(`Local: http://127.0.0.1:${port}`));
