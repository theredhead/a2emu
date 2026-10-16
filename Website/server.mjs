import {createServer} from 'node:http';
import {createReadStream} from 'node:fs';
import {mkdir,stat} from 'node:fs/promises';
import {resolve,extname,sep,basename} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {DatabaseSync} from 'node:sqlite';

export async function createSite({root=fileURLToPath(new URL('./dist/',import.meta.url)),dataDir=process.env.DATA_DIR || '/data'}={}) {
  root=resolve(root);
  await mkdir(dataDir,{recursive:true});
  const db=new DatabaseSync(resolve(dataDir,'counts.sqlite'));
  db.exec(`PRAGMA journal_mode=WAL; PRAGMA busy_timeout=5000;
    CREATE TABLE IF NOT EXISTS daily(day TEXT PRIMARY KEY,pageviews INTEGER NOT NULL DEFAULT 0,visits INTEGER NOT NULL DEFAULT 0);
    CREATE TABLE IF NOT EXISTS sessions(day TEXT NOT NULL,hash TEXT NOT NULL,PRIMARY KEY(day,hash));
    CREATE TABLE IF NOT EXISTS downloads(day TEXT NOT NULL,file TEXT NOT NULL,count INTEGER NOT NULL DEFAULT 0,PRIMARY KEY(day,file));`);
  const day=()=>new Date().toISOString().slice(0,10);
  const visit=db.prepare('INSERT OR IGNORE INTO sessions(day,hash) VALUES(?,?)');
  const incrementView=db.prepare(`INSERT INTO daily(day,pageviews,visits) VALUES(?,1,?) ON CONFLICT(day) DO UPDATE SET pageviews=pageviews+1,visits=visits+excluded.visits`);
  const incrementDownload=db.prepare('INSERT INTO downloads(day,file,count) VALUES(?,?,1) ON CONFLICT(day,file) DO UPDATE SET count=count+1');
  const total=db.prepare('SELECT COALESCE(SUM(pageviews),0) AS pageviews,COALESCE(SUM(visits),0) AS visits FROM daily');
  const downloadTotals=db.prepare('SELECT file,SUM(count) AS count FROM downloads GROUP BY file ORDER BY file');
  function countView(token) {
    const today=day();
    const hash=createHash('sha256').update(today+'\0'+token).digest('hex');
    db.exec('BEGIN');
    try {
      const unique=visit.run(today,hash).changes;
      incrementView.run(today,Number(unique));
      db.prepare('DELETE FROM sessions WHERE day < ?').run(today);
      db.exec('COMMIT');
    } catch(error) { db.exec('ROLLBACK');throw error; }
  }
  const types={'.html':'text/html; charset=utf-8','.css':'text/css; charset=utf-8','.js':'text/javascript; charset=utf-8','.png':'image/png','.zip':'application/zip','.txt':'text/plain; charset=utf-8','.sha256':'text/plain; charset=utf-8','.xml':'application/xml'};
  const json=(res,status,value)=>res.writeHead(status,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'}).end(JSON.stringify(value));
  const server=createServer(async(req,res)=>{
    res.setHeader('X-Content-Type-Options','nosniff');
    res.setHeader('Referrer-Policy','strict-origin-when-cross-origin');
    res.setHeader('Content-Security-Policy',"default-src 'self'; img-src 'self'; style-src 'self'; script-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'");
    try {
      const url=new URL(req.url,'http://localhost');
      if(url.pathname==='/healthz') {json(res,200,{ok:true});return;}
      if(url.pathname==='/api/stats' && req.method==='GET') {
        const files=downloadTotals.all();
        json(res,200,{...total.get(),builderDownloads:files.filter(f=>/^Apple-(?:II-Wrapper|IIGS-Player)-Builder-.*\.zip$/.test(f.file)).reduce((sum,f)=>sum+f.count,0),downloads:files});return;
      }
      if(url.pathname==='/api/visit' && req.method==='POST') {
        // Same-origin browser requests only. No IP address or user-agent is stored.
        const origin=req.headers.origin;
        if(req.headers['sec-fetch-site']==='cross-site' || (origin && new URL(origin).host!==req.headers.host)) {json(res,403,{error:'Origin not allowed'});return;}
        let body='';
        for await(const chunk of req) {body+=chunk;if(body.length>256){json(res,413,{error:'Request too large'});return;}}
        let value;try{value=JSON.parse(body);}catch{json(res,400,{error:'Invalid JSON'});return;}
        if(typeof value.session!=='string' || !/^[a-zA-Z0-9-]{16,80}$/.test(value.session)){json(res,400,{error:'Invalid session'});return;}
        if(!/bot|crawler|spider|preview/i.test(req.headers['user-agent'] || '')) countView(value.session);
        json(res,200,{ok:true});return;
      }
      if(req.method!=='GET' && req.method!=='HEAD') {res.setHeader('Allow','GET, HEAD');res.writeHead(405).end();return;}
      const path=resolve(root,'.'+decodeURIComponent(url.pathname.endsWith('/')?url.pathname+'index.html':url.pathname));
      if(!path.startsWith(root+sep)){res.writeHead(403).end();return;}
      let info;try{info=await stat(path);}catch{res.writeHead(404).end('Not found');return;}
      if(!info.isFile()){res.writeHead(404).end('Not found');return;}
      const etag=`"${info.size}-${Math.trunc(info.mtimeMs)}"`;
      res.setHeader('ETag',etag);
      res.setHeader('Content-Type',types[extname(path)] || 'application/octet-stream');
      res.setHeader('Cache-Control',path.includes(`${sep}downloads${sep}`)?'public, max-age=3600':'no-cache');
      if(req.headers['if-none-match']===etag){res.writeHead(304).end();return;}
      let start=0,end=info.size-1,status=200;
      if(req.headers.range){
        const match=/^bytes=(\d*)-(\d*)$/.exec(req.headers.range);
        if(!match || (!match[1]&&!match[2])){res.writeHead(416,{'Content-Range':`bytes */${info.size}`}).end();return;}
        if(!match[1]) start=Math.max(0,info.size-Number(match[2]));
        else {start=Number(match[1]);if(match[2])end=Math.min(Number(match[2]),end);}
        if(start>end || start>=info.size){res.writeHead(416,{'Content-Range':`bytes */${info.size}`}).end();return;}
        status=206;res.setHeader('Content-Range',`bytes ${start}-${end}/${info.size}`);
      }
      res.setHeader('Accept-Ranges','bytes');res.setHeader('Content-Length',Math.max(0,end-start+1));
      if(path.includes(`${sep}downloads${sep}`) && extname(path)==='.zip') {
        res.setHeader('Content-Disposition',`attachment; filename="${basename(path)}"`);
        if(req.method==='GET' && start===0 && !/bot|crawler|spider|preview/i.test(req.headers['user-agent'] || '')) {
          res.once('finish',()=>{try{incrementDownload.run(day(),basename(path));}catch{console.error('Download count could not be saved');}});
        }
      }
      res.writeHead(status);
      if(req.method==='HEAD' || info.size===0)res.end();
      else createReadStream(path,{start,end}).on('error',()=>res.destroy()).pipe(res);
    } catch {if(!res.headersSent)json(res,500,{error:'Server error'});else res.destroy();}
  });
  server.on('close',()=>db.close());
  return server;
}
if(process.argv[1] && resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
  const server=await createSite({root:process.env.PUBLIC_DIR || fileURLToPath(new URL('./public/',import.meta.url))});
  server.listen(Number(process.env.PORT || 8080),'0.0.0.0',()=>console.log(`a2emu listening on ${process.env.PORT || 8080}`));
  for(const signal of ['SIGTERM','SIGINT'])process.on(signal,()=>server.close(()=>process.exit(0)));
}
