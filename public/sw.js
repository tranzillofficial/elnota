const CACHE='elnota-v3';
const SHELL=['/dashboard','/demo','/offline.html','/manifest.webmanifest','/icon-192.png','/icon-512.png'];
let preparing;
async function prepareOffline(){
 if(preparing)return preparing;
 preparing=(async()=>{const cache=await caches.open(CACHE);
  try{const files=await fetch('/offline-assets.json',{cache:'no-store'});if(!files.ok)throw new Error('Missing asset list');const assets=await files.json();if(!Array.isArray(assets))throw new Error('Invalid asset list');await cache.addAll(assets.filter(p=>typeof p==='string'&&p.startsWith('/_next/static/')))}catch(error){if(!(await cache.match('/offline-ready')))throw error}
  try{await cache.addAll(SHELL)}catch(error){if(!(await cache.match('/offline-ready')))throw error}
  await cache.put('/offline-ready',new Response('ready'));
 })().finally(()=>{preparing=null});return preparing;
}
self.addEventListener('install',event=>{event.waitUntil(prepareOffline().then(()=>self.skipWaiting()))});
self.addEventListener('activate',event=>{event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k.startsWith('elnota-')&&k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim()))});
self.addEventListener('message',event=>{if(event.data?.type==='PREPARE_OFFLINE')event.waitUntil(prepareOffline().then(()=>event.ports[0]?.postMessage({ok:true})).catch(()=>event.ports[0]?.postMessage({ok:false,error:'اتصل بالإنترنت لتجهيز ملفات التطبيق مرة واحدة.'})))});
self.addEventListener('fetch',event=>{const req=event.request,url=new URL(req.url);if(req.method!=='GET'||url.origin!==self.location.origin||url.pathname.startsWith('/api/')||url.pathname.includes('/auth/')||req.headers.get('RSC'))return;
 if(req.mode==='navigate'&&['/dashboard','/demo'].includes(url.pathname)){event.respondWith(fetch(req).then(async res=>{if(res.ok)await (await caches.open(CACHE)).put(url.pathname,res.clone());return res}).catch(async()=>await (await caches.open(CACHE)).match(url.pathname)||await caches.match('/offline.html')));return}
 if(url.pathname.startsWith('/_next/static/')||url.pathname.startsWith('/icon-')||url.pathname==='/manifest.webmanifest')event.respondWith(caches.open(CACHE).then(async cache=>await cache.match(req)||fetch(req).then(async res=>{if(res.ok)await cache.put(req,res.clone());return res})))
});
