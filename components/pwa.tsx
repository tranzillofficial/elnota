'use client';
import { useEffect, useState } from 'react';
import { Download, X } from 'lucide-react';
interface InstallPrompt extends Event { prompt():Promise<void>;userChoice:Promise<{outcome:string}> }
export function PWA(){const [prompt,setPrompt]=useState<InstallPrompt|null>(null);const [ios,setIos]=useState(false);const [hidden,setHidden]=useState(true);
useEffect(()=>{if('serviceWorker' in navigator)navigator.serviceWorker.register('/sw.js').catch(()=>{});setHidden(sessionStorage.getItem('install-dismissed')==='1');setIos(/iPad|iPhone|iPod/.test(navigator.userAgent)&&!window.matchMedia('(display-mode: standalone)').matches);const handler=(e:Event)=>{e.preventDefault();setPrompt(e as InstallPrompt)};window.addEventListener('beforeinstallprompt',handler);return ()=>window.removeEventListener('beforeinstallprompt',handler)},[]);
if(hidden||(!prompt&&!ios))return null;return <aside className="install-banner"><Download size={20}/><div><strong>النوتة على شاشة موبايلك</strong><small>{ios?'من Safari: مشاركة ← إضافة إلى الشاشة الرئيسية':'ثبّت التطبيق وافتح حساباتك بضغطة واحدة'}</small></div>{prompt&&<button onClick={async()=>{await prompt.prompt();await prompt.userChoice;setPrompt(null)}}>تثبيت</button>}<button className="icon-button" aria-label="إغلاق" onClick={()=>{setHidden(true);sessionStorage.setItem('install-dismissed','1')}}><X size={18}/></button></aside>}
