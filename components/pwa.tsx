'use client';
import {createContext,useContext,useCallback,useEffect,useRef,useState} from 'react';
interface InstallPrompt extends Event {prompt():Promise<void>;userChoice:Promise<{outcome:string}>}
type PWAState={prompt:InstallPrompt|null;ios:boolean;installed:boolean;offlineReady:boolean;preparing:boolean;error:string;install:()=>void;prepareOffline:()=>Promise<void>};
const Context=createContext<PWAState|null>(null);
function bounded<T>(task:Promise<T>,ms=5000):Promise<T>{return new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(new Error('تعذر تحديث ملفات التطبيق. يمكنك استخدام النسخة المحفوظة.')),ms);task.then(v=>{clearTimeout(timer);resolve(v)},e=>{clearTimeout(timer);reject(e)})})}
export function usePWA(){const value=useContext(Context);if(!value)throw new Error('PWA provider missing');return value}
export function PWAProvider({children}:{children:React.ReactNode}){
 const [prompt,setPrompt]=useState<InstallPrompt|null>(null);const [ios,setIos]=useState(false);const [installed,setInstalled]=useState(false);const [offlineReady,setReady]=useState(false);const [preparing,setPreparing]=useState(false);const [error,setError]=useState('');const pending=useRef<Promise<void>|null>(null);
 const prepareOffline=useCallback(()=>{if(pending.current)return pending.current;const task=(async()=>{setPreparing(true);setError('');try{
 if(!('serviceWorker' in navigator))throw new Error('هذا المتصفح لا يدعم العمل بدون إنترنت. استخدم Chrome أو Edge أو Safari.');
 let registration=await navigator.serviceWorker.getRegistration('/');
 if(!registration)registration=await bounded(navigator.serviceWorker.register('/sw.js'),15000);
 else if(navigator.onLine){try{await bounded(registration.update())}catch(e){if(!registration.active)throw e}}
 const worker=registration.installing||registration.waiting||registration.active;if(!worker)throw new Error('التطبيق لم يجهز بعد. جرّب مرة أخرى.');
 if(worker.state!=='activated')await new Promise<void>((resolve,reject)=>{const done=()=>{if(worker.state==='activated'){clearTimeout(timer);worker.removeEventListener('statechange',done);resolve()}else if(worker.state==='redundant'){clearTimeout(timer);worker.removeEventListener('statechange',done);reject(new Error('تعذر تجهيز ملفات التطبيق. تأكد من الاتصال بالإنترنت.'))}};const timer=setTimeout(()=>{worker.removeEventListener('statechange',done);reject(new Error('تأكد من اتصال الإنترنت ثم جرّب مرة أخرى.'))},20000);worker.addEventListener('statechange',done);done()});
 await new Promise<void>((resolve,reject)=>{const channel=new MessageChannel();const timeout=setTimeout(()=>{channel.port1.close();reject(new Error('تعذر حفظ كل ملفات التطبيق. اتصل بالإنترنت وجرّب مرة أخرى.'))},20000);channel.port1.onmessage=e=>{clearTimeout(timeout);channel.port1.close();e.data?.ok?resolve():reject(new Error(e.data?.error||'تعذر التجهيز'))};worker.postMessage({type:'PREPARE_OFFLINE'},[channel.port2])});
 setReady(true);try{await navigator.storage?.persist?.()}catch{/* Cache readiness does not depend on a persistence grant. */}
 }catch(e){setReady(false);setError((e as Error).message)}finally{setPreparing(false)}})();pending.current=task;void task.finally(()=>{pending.current=null});return task},[]);
 useEffect(()=>{const mode=window.matchMedia('(display-mode: standalone)');const detect=()=>setInstalled(mode.matches||Boolean((navigator as Navigator&{standalone?:boolean}).standalone));detect();setIos(/iPad|iPhone|iPod/.test(navigator.userAgent)||(navigator.platform==='MacIntel'&&navigator.maxTouchPoints>1));const before=(event:Event)=>{event.preventDefault();setPrompt(event as InstallPrompt)};const done=()=>{setPrompt(null);setInstalled(true)};window.addEventListener('beforeinstallprompt',before);window.addEventListener('appinstalled',done);mode.addEventListener('change',detect);void prepareOffline();return()=>{window.removeEventListener('beforeinstallprompt',before);window.removeEventListener('appinstalled',done);mode.removeEventListener('change',detect)}},[prepareOffline]);
 function install(){if(prompt){const current=prompt;setPrompt(null);void current.prompt().then(()=>current.userChoice).catch(()=>setError('استخدم خيار تثبيت التطبيق من قائمة المتصفح.'));}else if(ios){setError('للتثبيت: Safari ← مشاركة ← إضافة إلى الشاشة الرئيسية ← إضافة.')}else{setError('افتح قائمة Chrome أو Edge واختر تثبيت النوتة أو إضافة إلى الشاشة الرئيسية.')}void prepareOffline()}
 return <Context.Provider value={{prompt,ios,installed,offlineReady,preparing,error,install,prepareOffline}}>{children}</Context.Provider>;
}
export function PWA(){return null}
