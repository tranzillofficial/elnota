const CACHE='elnota-v1';const SHELL=['/dashboard','/demo','/offline.html','/icon-192.png','/icon-512.png'];
self.addEventListener('install',event=>{event.waitUntil(caches.open(CACHE).then(c=>c.addAll(SHELL)));self.skipWaiting()});
self.addEventListener('activate',event=>{event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k!==CACHE).map(k=>caches.delete(k)))));self.clients.claim()});
self.addEventListener('fetch',event=>{const req=event.request;const url=new URL(req.url);if(req.method!=='GET'||url.origin!==self.location.origin||url.pathname.startsWith('/api/')||url.pathname.includes('/auth/')||req.headers.get('RSC'))return;
if(req.mode==='navigate'){if(!['/dashboard','/demo'].includes(url.pathname))return;event.respondWith(fetch(req).then(res=>{if(res.ok){const copy=res.clone();caches.open(CACHE).then(c=>c.put(url.pathname,copy))}return res}).catch(async()=>await caches.match(url.pathname)||await caches.match('/offline.html')));return}
if(url.pathname.startsWith('/_next/static/')||url.pathname.startsWith('/icon-'))event.respondWith(caches.match(req).then(cached=>cached||fetch(req).then(res=>{if(res.ok){const copy=res.clone();caches.open(CACHE).then(c=>c.put(req,copy))}return res})))
});
