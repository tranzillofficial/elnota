// Real IndexedDB transaction semantics using fake-indexeddb; no network or production fixtures.
const assert=require('node:assert/strict'),fs=require('node:fs');
require(process.env.BACKUP_TEST_DEPS+'/fake-indexeddb/auto');
(async()=>{const {stripTypeScriptTypes}=require('node:module'),{pathToFileURL}=require('node:url');const dir=fs.mkdtempSync('/tmp/elnota-queue-modules-');
fs.writeFileSync(dir+'/model.mjs',stripTypeScriptTypes(fs.readFileSync('lib/model.ts','utf8')));
fs.writeFileSync(dir+'/storage.mjs',stripTypeScriptTypes(fs.readFileSync('lib/storage.ts','utf8')).replace(/import\s*\{\s*\}\s*from[^;]+;/g,'').replace("'./model'",JSON.stringify(pathToFileURL(dir+'/model.mjs').href)).replace("'idb'",JSON.stringify(pathToFileURL(require.resolve('idb')).href)));
const model=await import(pathToFileURL(dir+'/model.mjs').href),storage=await import(pathToFileURL(dir+'/storage.mjs').href);
const user='local-a',data=model.emptyLedger('Queue test');data.products=[{id:'p',name:'Product',barcode:'',price:10,image:'local-image',archived:false}];
await Promise.all(Array.from({length:10},()=>storage.stageDailyBackup(user,data,'2026-10-19',Date.parse('2026-10-18T21:00:00Z'))));
let queue=await storage.getMeta('daily-queue:'+user);assert.equal(queue.length,1);assert.equal(queue[0].data.products[0].image,undefined);const first=queue[0];
// A failed upload never acknowledges or removes the durable local copy.
assert.equal((await storage.stageDailyBackup(user,data,'2026-10-19')).queue[0].id,first.id);
await storage.stageDailyBackup(user,data,'2026-10-20');await storage.acknowledgeDailyBackup(user,first.id,{id:first.id,backup_day:first.day,captured_at:first.capturedAt,uploaded_at:new Date().toISOString(),size_bytes:123});
queue=await storage.getMeta('daily-queue:'+user);assert.equal(queue.length,1);assert.equal(queue[0].day,'2026-10-20');assert.equal((await storage.getMeta('daily-upload:'+user)).id,first.id);
for(let d=21;d<=29;d++)await storage.stageDailyBackup(user,data,'2026-10-'+d);queue=await storage.getMeta('daily-queue:'+user);assert.equal(queue.length,7);assert.equal(queue.at(-1).day,'2026-10-29');
assert.equal(await storage.getMeta('daily-queue:another-user'),undefined);
await assert.rejects(()=>storage.stageDailyBackup('oversize',{...data,settings:{...data.settings,address:'x'.repeat(11*1024*1024)}},'2026-10-19'));
assert.equal(await storage.getMeta('daily-day:oversize'),undefined);
console.log('PASS durable daily queue, concurrent tabs, stable retries, no sync overwrite, image exclusion, retention, account isolation and oversize rejection');})().catch(e=>{console.error(e);process.exit(1)});
