import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,mkdir,writeFile,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {once} from 'node:events';
import {createSite} from './server.mjs';

test('counts, downloads, ranges, privacy boundaries and restart persistence',async()=>{
  const folder=await mkdtemp(join(tmpdir(),'a2emu-server-'));
  const root=join(folder,'public'),dataDir=join(folder,'data');
  await mkdir(join(root,'downloads'),{recursive:true});
  await writeFile(join(root,'index.html'),'<h1>a2emu</h1>');
  await writeFile(join(root,'downloads','Apple-IIGS-Player-Builder-test-universal.zip'),'0123456789');
  let server;
  async function start(){server=await createSite({root,dataDir});server.listen(0,'127.0.0.1');await once(server,'listening');return `http://127.0.0.1:${server.address().port}`;}
  async function stop(){await new Promise(r=>server.close(r));}
  let base=await start();
  const stats=async()=> (await fetch(base+'/api/stats')).json();
  const visit=(session='browser-session-0001',extra={})=>fetch(base+'/api/visit',{method:'POST',headers:{'Content-Type':'application/json',...extra},body:JSON.stringify({session})});
  try {
    assert.equal((await fetch(base+'/healthz')).status,200);
    assert.match(await (await fetch(base+'/')).text(),/a2emu/);
    await visit();await visit();
    let count=await stats();assert.equal(count.visits,1);assert.equal(count.pageviews,2);
    await visit('browser-session-0002');assert.equal((await stats()).visits,2);
    assert.equal((await visit('browser-session-0003',{'Origin':'https://elsewhere.invalid'})).status,403);
    assert.equal((await visit('bad')).status,400);
    await visit('browser-session-bot',{'User-Agent':'SearchBot'});assert.equal((await stats()).visits,2);
    await Promise.all(Array.from({length:12},()=>visit()));assert.equal((await stats()).visits,2);assert.equal((await stats()).pageviews,15);
    const url=base+'/downloads/Apple-IIGS-Player-Builder-test-universal.zip';
    await fetch(url,{method:'HEAD'});assert.equal((await stats()).builderDownloads,0);
    const download=await fetch(url);assert.equal(download.headers.get('content-type'),'application/zip');assert.equal(await download.text(),'0123456789');
    assert.equal((await stats()).builderDownloads,1);
    const range=await fetch(url,{headers:{Range:'bytes=2-5'}});assert.equal(range.status,206);assert.equal(await range.text(),'2345');assert.equal((await stats()).builderDownloads,1);
    assert.equal((await fetch(url,{headers:{Range:'bytes=20-30'}})).status,416);
    assert.equal((await fetch(base+'/missing')).status,404);
    await stop();base=await start();count=await stats();assert.equal(count.visits,2);assert.equal(count.builderDownloads,1);assert.equal(count.pageviews,15);
    const response=await fetch(base+'/');assert.equal(response.headers.get('set-cookie'),null);
  } finally {await stop();await rm(folder,{recursive:true,force:true});}
});
