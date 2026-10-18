'use client';
import {useEffect,useRef,useState} from 'react';
import {supabase} from '@/lib/supabase';
import {backupDue,cloudStatus} from '@/lib/cloud-subscription';
export function useDailyBackup({userId,until,demo,sync}:{userId:string;until:string|null|undefined;demo:boolean;sync:()=>Promise<void>}){
 const latest=useRef(sync);latest.current=sync;const working=useRef(false);const [message,setMessage]=useState('');
 useEffect(()=>{if(demo||!userId||!supabase)return;let alive=true;
 async function check(){if(!alive||working.current||!navigator.onLine||document.visibilityState==='hidden'||!cloudStatus(until).active)return;working.current=true;
 try{const {data,error}=await supabase!.from('elnota_daily_backups').select('updated_at').eq('user_id',userId).maybeSingle();if(error)throw error;if(!backupDue(data?.updated_at)){if(alive)setMessage('آخر نسخة يومية: '+new Date(data!.updated_at).toLocaleString('ar-EG'));return;}await latest.current();if(!alive)return;const result=await supabase!.rpc('elnota_daily_snapshot');if(result.error)throw result.error;if(alive)setMessage('تم حفظ النسخة اليومية في الكلاود: '+new Date(result.data).toLocaleString('ar-EG'))}
 catch(e){if(alive)setMessage('النسخة اليومية لم تُحدّث؛ بيانات الجهاز محفوظة. '+(e as Error).message)}finally{working.current=false}}
 void check();const timer=setInterval(()=>void check(),60000);const resume=()=>void check();window.addEventListener('online',resume);window.addEventListener('focus',resume);document.addEventListener('visibilitychange',resume);return()=>{alive=false;clearInterval(timer);window.removeEventListener('online',resume);window.removeEventListener('focus',resume);document.removeEventListener('visibilitychange',resume)};
 },[userId,until,demo]);return message;
}
