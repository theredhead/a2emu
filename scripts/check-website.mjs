import {readFile,stat} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {resolve} from 'node:path';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const root=fileURLToPath(new URL('../Website/dist/',import.meta.url));
const html=await readFile(resolve(root,'index.html'),'utf8');
assert(!/__VERSION__|__SIZE__/.test(html),'Unresolved release placeholders');
const ids=new Set([...html.matchAll(/\bid="([^"]+)"/g)].map(m=>m[1]));
const urls=[...html.matchAll(/(?:href|src)="([^"]+)"/g)].map(m=>m[1]);
for(const url of urls){
 if(url.startsWith('#')) {assert(url==='#'||ids.has(url.slice(1)),`Missing anchor ${url}`);continue;}
 if(/^https?:/.test(url))continue;
 assert((await stat(resolve(root,url))).isFile(),`Missing local asset ${url}`);
}
const checksum=urls.find(u=>u.endsWith('.sha256'));
const [expected,name]=(await readFile(resolve(root,checksum),'utf8')).trim().split(/\s+/);
const digest=createHash('sha256').update(await readFile(resolve(root,'downloads',name))).digest('hex');
assert.equal(digest,expected,'Download checksum mismatch');
console.log('All local links, assets, anchors, release placeholders and download checksum passed.');
