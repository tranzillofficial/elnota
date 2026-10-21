import { openDB } from 'idb';
import { type Ledger,type Account, validateLedger } from './model';
import { type SyncBaseline } from './sync-plan';
const db=()=>openDB('elnota-v1',1,{upgrade(d){d.createObjectStore('ledgers');d.createObjectStore('meta')}});
export async function loadLedger(user:string):Promise<Ledger|null>{const d=await db();return (await d.get('ledgers',user))||null}
export async function saveLedger(user:string,data:Ledger){if(!validateLedger(data))throw new Error('بيانات غير صالحة');const d=await db();await d.put('ledgers',data,user)}
export async function getMeta<T>(key:string):Promise<T|undefined>{return (await db()).get('meta',key)}
export async function setMeta(key:string,value:unknown){await (await db()).put('meta',value,key)}
export async function localAccount(){const d=await db();const uid=await d.get('meta','active-user');if(typeof uid!=='string')return null;const [account,ledger]=await Promise.all([d.get('meta','account:'+uid),d.get('ledgers',uid)]);return account?.user_id===uid&&validateLedger(ledger)?{uid,account:account as Account,ledger}:null}
export async function saveSyncBaseline(user:string,baseline:SyncBaseline){const tx=(await db()).transaction('meta','readwrite');await tx.store.put(baseline,'sync-baseline:'+user);await tx.store.put(baseline.revision,'revision:'+user);await tx.done}
export type SyncRecovery={id:string;at:string;reason:string;data:Ledger};
export async function saveSyncRecovery(user:string,data:Ledger,reason:string){const d=await db();const tx=d.transaction('meta','readwrite');const key='sync-recovery:'+user;const old=(await tx.store.get(key)||[]) as SyncRecovery[];await tx.store.put([{id:crypto.randomUUID(),at:new Date().toISOString(),reason,data},...old].slice(0,3),key);await tx.done}
export function cloudPayload(data:Ledger):Ledger{return {...data,syncImages:undefined,products:data.products.map(({image,...p})=>p)}}
export async function exportBackup(data:Ledger){const file=new File([JSON.stringify({application:'ElNota',exportedAt:new Date().toISOString(),data},null,2)],`elnota-${new Date().toISOString().slice(0,10)}.json`,{type:'application/json'});if(navigator.canShare?.({files:[file]})){try{await navigator.share({files:[file],title:'نسخة احتياطية للنوتة'});return}catch(e){if((e as Error).name==='AbortError')return}}
const url=URL.createObjectURL(file);const a=document.createElement('a');a.href=url;a.download=file.name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000)}
export async function readBackup(file:File):Promise<Ledger>{if(file.size>50*1024*1024)throw new Error('الحد الأقصى لملف النسخة 50 MB');const json=JSON.parse(await file.text());const data=json.data||json;if(!validateLedger(data))throw new Error('الملف ليس نسخة نوتة صالحة');return data}
export async function compressImage(file:File):Promise<string>{if(!file.type.startsWith('image/'))throw new Error('اختر صورة');if(file.size>20*1024*1024)throw new Error('اختر صورة أصغر من 20 MB');const bitmap=await createImageBitmap(file);const canvas=document.createElement('canvas');const scale=Math.min(1,600/Math.max(bitmap.width,bitmap.height));canvas.width=bitmap.width*scale;canvas.height=bitmap.height*scale;canvas.getContext('2d')!.drawImage(bitmap,0,0,canvas.width,canvas.height);bitmap.close();return canvas.toDataURL('image/jpeg',0.75)}

export type PendingDailyBackup={id:string;day:string;capturedAt:string;data:Ledger};
// One durable snapshot per Cairo day, independent from optional two-way sync.
export async function stageDailyBackup(user:string,data:Ledger,day:string,now=Date.now()){
 const payload=cloudPayload(data);if(new Blob([JSON.stringify(payload)]).size>10*1024*1024)throw new Error('النسخة أكبر من 10 MB. صدّر نسخة محلية وتواصل مع الإدارة.');
 const d=await db(),tx=d.transaction('meta','readwrite');const key='daily-queue:'+user;
 let queue=(await tx.store.get(key)||[]) as PendingDailyBackup[];const last=await tx.store.get('daily-day:'+user);
 if(!last||last<day){queue=[...queue,{id:crypto.randomUUID(),day,capturedAt:new Date(now).toISOString(),data:payload}].slice(-7);await tx.store.put(queue,key);await tx.store.put(day,'daily-day:'+user)}
 let device=await tx.store.get('backup-device:'+user);if(!device){device=crypto.randomUUID();await tx.store.put(device,'backup-device:'+user)}
 await tx.done;return {queue,device:device as string};
}
export async function acknowledgeDailyBackup(user:string,id:string,info:import('./cloud-subscription').DeviceBackupInfo){
 const tx=(await db()).transaction('meta','readwrite'),key='daily-queue:'+user;
 const queue=(await tx.store.get(key)||[]) as PendingDailyBackup[];await tx.store.put(queue.filter(q=>q.id!==id),key);await tx.store.put(info,'daily-upload:'+user);await tx.done;
}
