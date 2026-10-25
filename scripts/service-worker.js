const CACHE='elnota-__CACHE_VERSION__';
const SHELL=['/dashboard','/demo','/login','/','/offline.html','/manifest.webmanifest','/icon-192.png','/icon-512.png'];
let preparing;
async function prepareOffline(){
 if(preparing)return preparing;
 preparing=(async()=>{const cache=await caches.open(CACHE);if(await cache.match('/offline-ready'))return;
  const files=await fetch('/offline-assets.json',{cache:'no-store'});if(!files.ok)throw new Error('Missing asset list');const assets=await files.json();if(!Array.isArray(assets)||!assets.length)throw new Error('Invalid asset list');
  await cache.addAll(assets.filter(p=>typeof p==='string'&&p.startsWith('/_next/static/')));await cache.addAll(SHELL);
  await cache.put('/offline-ready',new Response('ready'));
 })().finally(()=>{preparing=null});return preparing;
}
self.addEventListener('install',event=>{event.waitUntil(prepareOffline().then(()=>self.skipWaiting()))});
self.addEventListener('activate',event=>{event.waitUntil(caches.keys().then(keys=>{const old=keys.filter(k=>k.startsWith('elnota-')&&k!==CACHE);return Promise.all(old.slice(0,-2).map(k=>caches.delete(k)))}).then(()=>self.clients.claim()))});
self.addEventListener('message',event=>{if(event.data?.type==='PREPARE_OFFLINE')event.waitUntil(prepareOffline().then(()=>event.ports[0]?.postMessage({ok:true})).catch(()=>event.ports[0]?.postMessage({ok:false,error:'اتصل بالإنترنت لتجهيز ملفات التطبيق مرة واحدة.'})))});
self.addEventListener('fetch',event=>{const req=event.request,url=new URL(req.url);if(req.method!=='GET'||url.origin!==self.location.origin||url.pathname.startsWith('/app/')||url.pathname==='/app'||url.pathname.startsWith('/api/')||url.pathname.includes('/auth/')||req.headers.get('RSC'))return;
 if(req.mode==='navigate'&&url.pathname==='/'){event.respondWith(fetch(req).catch(()=>caches.open(CACHE).then(cache=>cache.match('/')||cache.match('/offline.html'))));return}
 // Keep HTML paired with the exact assets cached for this build, without waiting for a failing network.
 if(req.mode==='navigate'&&SHELL.includes(url.pathname)){event.respondWith(caches.open(CACHE).then(async cache=>await cache.match(url.pathname)||fetch(req).catch(async()=>await cache.match('/offline.html'))));return}
 if(url.pathname.startsWith('/_next/static/')||url.pathname.startsWith('/icon-')||url.pathname==='/manifest.webmanifest')event.respondWith(caches.match(req).then(cached=>cached||fetch(req)))
});
