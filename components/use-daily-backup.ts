'use client';
import {useEffect,useRef,useState} from 'react';
import {supabase} from '@/lib/supabase';
import {backupDay,backupCheckDelay,cloudStatus,type DeviceBackupInfo} from '@/lib/cloud-subscription';
import {stageDailyBackup,acknowledgeDailyBackup,getMeta,loadLedger} from '@/lib/storage';
import {isPristine} from '@/lib/sync-plan';
import type {Ledger} from '@/lib/model';
export type DailyBackupState={message:string;pending:number;lastUploaded:DeviceBackupInfo|null;working:boolean;error:boolean};
export function useDailyBackup({userId,until,demo,ledger}:{userId:string;until:string|null|undefined;demo:boolean;ledger:Ledger|null}){
 const latest=useRef(ledger);latest.current=ledger;const [state,setState]=useState<DailyBackupState>({message:'',pending:0,lastUploaded:null,working:false,error:false});
 useEffect(()=>{if(demo||!userId||!supabase||!ledger)return;let alive=true,working=false,timer:ReturnType<typeof setTimeout>;
 const update=(value:Partial<DailyBackupState>)=>{if(alive)setState(s=>({...s,...value}))};
 async function check(){if(!alive||working)return;working=true;
 try{
 const lastUploaded=await getMeta<DeviceBackupInfo>('daily-upload:'+userId)||null;update({lastUploaded});
 if(!cloudStatus(until).active){update({message:'النسخ السحابي يحتاج اشتراك Cloud نشط.',working:false});return}
 const snapshot=await loadLedger(userId)||latest.current!;
 if(isPristine(snapshot)&&!await getMeta('sync-baseline:'+userId)&&!(await getMeta<unknown[]>('daily-queue:'+userId))?.length){update({message:'لا تُرفع نسخة فارغة من جهاز جديد قبل مزامنة بياناته أو تسجيل أول بيانات.'});return}
 const {queue,device}=await stageDailyBackup(userId,snapshot,backupDay());if(!alive)return;
 update({pending:queue.length,error:false});
 if(!navigator.onLine){update({message:queue.length?'النسخة محفوظة على الجهاز وتنتظر رجوع الإنترنت.':'الحفظ المحلي يعمل بدون إنترنت.'});return}
 if(!queue.length){const r=await supabase!.from('elnota_device_backup_files').select('id,backup_day,captured_at,uploaded_at,size_bytes').eq('user_id',userId).order('uploaded_at',{ascending:false}).limit(1).abortSignal(AbortSignal.timeout(15000)).maybeSingle();if(r.error)throw r.error;update({lastUploaded:r.data||lastUploaded,message:r.data?'النسخة اليومية مرفوعة.':'سيتم تجهيز نسخة اليوم تلقائيًا.'});return}
 update({working:true,message:'جارٍ رفع النسخة اليومية…'});
 const auth=await supabase!.auth.getSession();if(auth.error)throw auth.error;if(auth.data.session?.user.id!==userId)throw new Error('سجّل الدخول بنفس الحساب لإتمام رفع النسخة المحفوظة.');
 for(const item of queue){if(!alive||!navigator.onLine)break;
 const {data,error}=await supabase!.rpc('elnota_upload_device_backup',{expected_user:userId,backup_id:item.id,device_id:device,backup_day:item.day,captured_at:item.capturedAt,payload:item.data}).abortSignal(AbortSignal.timeout(15000));if(error)throw error;
 await acknowledgeDailyBackup(userId,item.id,data as DeviceBackupInfo);update({lastUploaded:data as DeviceBackupInfo});
 }
 const pending=(await getMeta<unknown[]>('daily-queue:'+userId)||[]).length;update({pending,message:pending?'توجد نسخ تنتظر رجوع الاتصال.':'تم رفع النسخة اليومية بنجاح.',error:false});
 }catch(e){update({error:true,message:'لم يكتمل النسخ. بياناتك الأصلية على الجهاز لم تتغير. '+(e as Error).message})}
 finally{working=false;update({working:false})}}
 async function tick(){await check();if(alive)timer=setTimeout(()=>void tick(),backupCheckDelay())}
 void tick();const resume=()=>{void check()};window.addEventListener('online',resume);window.addEventListener('focus',resume);document.addEventListener('visibilitychange',resume);
 return()=>{alive=false;clearTimeout(timer);window.removeEventListener('online',resume);window.removeEventListener('focus',resume);document.removeEventListener('visibilitychange',resume)};
 },[userId,until,demo,!!ledger]);return state;
}
