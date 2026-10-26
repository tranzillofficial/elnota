import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {runInNewContext} from 'node:vm';

function browser(standalone=false){
 const listeners:Record<string,(event?:any)=>void>={};
 const window:any={addEventListener:(name:string,fn:any)=>{listeners[name]=fn},matchMedia:()=>({matches:standalone})};
 const html=readFileSync(new URL('../flutter/web/index.html',import.meta.url),'utf8');
 const script=html.match(/<script>([\s\S]*?)<\/script>/)![1];
 runInNewContext(script,{window,navigator:{standalone:false}});
 return {window,listeners};
}
test('browser install stays deferred until settings action',async()=>{
 const {window,listeners}=browser();let prevented=false,calls=0;
 listeners.beforeinstallprompt({preventDefault(){prevented=true},async prompt(){calls++},userChoice:Promise.resolve({outcome:'accepted'})});
 assert.equal(prevented,true);assert.equal(calls,0);
 assert.match(await window.elnotaInstallShortcut(),/تم طلب/);assert.equal(calls,1);
 assert.match(await window.elnotaInstallShortcut(),/قائمة المتصفح/);assert.equal(calls,1);
});
test('installed shortcut does not request installation again',async()=>{
 const {window}=browser(true);
 assert.match(await window.elnotaInstallShortcut(),/مثبت بالفعل/);
});
test('installation cancellation is reported and completed installs clear the prompt',async()=>{
 const {window,listeners}=browser();
 listeners.beforeinstallprompt({preventDefault(){},async prompt(){},userChoice:Promise.resolve({outcome:'dismissed'})});
 assert.match(await window.elnotaInstallShortcut(),/إلغاء/);
 listeners.appinstalled();
 assert.match(await window.elnotaInstallShortcut(),/قائمة المتصفح/);
});
