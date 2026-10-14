import { openDB } from 'idb';
import { type Ledger, validateLedger } from './model';
const db=()=>openDB('elnota-v1',1,{upgrade(d){d.createObjectStore('ledgers');d.createObjectStore('meta')}});
export async function loadLedger(user:string):Promise<Ledger|null>{const d=await db();return (await d.get('ledgers',user))||null}
export async function saveLedger(user:string,data:Ledger){if(!validateLedger(data))throw new Error('بيانات غير صالحة');const d=await db();await d.put('ledgers',data,user)}
export async function getMeta<T>(key:string):Promise<T|undefined>{return (await db()).get('meta',key)}
export async function setMeta(key:string,value:unknown){await (await db()).put('meta',value,key)}
export function cloudPayload(data:Ledger):Ledger{return {...data,products:data.products.map(({image,...p})=>p)}}
export async function exportBackup(data:Ledger){const file=new File([JSON.stringify({application:'ElNota',exportedAt:new Date().toISOString(),data},null,2)],`elnota-${new Date().toISOString().slice(0,10)}.json`,{type:'application/json'});if(navigator.canShare?.({files:[file]})){try{await navigator.share({files:[file],title:'نسخة احتياطية للنوتة'});return}catch(e){if((e as Error).name==='AbortError')return}}
const url=URL.createObjectURL(file);const a=document.createElement('a');a.href=url;a.download=file.name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000)}
export async function readBackup(file:File):Promise<Ledger>{if(file.size>50*1024*1024)throw new Error('الحد الأقصى لملف النسخة 50 MB');const json=JSON.parse(await file.text());const data=json.data||json;if(!validateLedger(data))throw new Error('الملف ليس نسخة نوتة صالحة');return data}
export async function compressImage(file:File):Promise<string>{if(!file.type.startsWith('image/'))throw new Error('اختر صورة');if(file.size>20*1024*1024)throw new Error('اختر صورة أصغر من 20 MB');const bitmap=await createImageBitmap(file);const canvas=document.createElement('canvas');const scale=Math.min(1,600/Math.max(bitmap.width,bitmap.height));canvas.width=bitmap.width*scale;canvas.height=bitmap.height*scale;canvas.getContext('2d')!.drawImage(bitmap,0,0,canvas.width,canvas.height);bitmap.close();return canvas.toDataURL('image/jpeg',0.75)}
