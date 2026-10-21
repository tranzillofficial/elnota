'use client';
import {useEffect,useRef} from 'react';
import {startCloudSync} from '@/lib/cloud-sync-runner';
export function useAutomaticSync({userId,enabled,online,changeKey,sync,onError,onSettled}:{userId:string;enabled:boolean;online:boolean;changeKey:string;sync:()=>Promise<void>;onError:(error:Error)=>void;onSettled:()=>void}){
 const latest=useRef({sync,onError,onSettled});latest.current={sync,onError,onSettled};const runner=useRef<ReturnType<typeof startCloudSync>|null>(null);
 useEffect(()=>{if(!userId||!enabled||!online)return;const current=startCloudSync({sync:()=>latest.current.sync(),onError:error=>latest.current.onError(error),onSettled:()=>latest.current.onSettled(),active:()=>navigator.onLine&&document.visibilityState!=='hidden',setTimer:(fn,delay)=>setTimeout(fn,delay),clearTimer:timer=>clearTimeout(timer)});runner.current=current;const wake=()=>current.wake();window.addEventListener('focus',wake);document.addEventListener('visibilitychange',wake);return()=>{current.stop();if(runner.current===current)runner.current=null;window.removeEventListener('focus',wake);document.removeEventListener('visibilitychange',wake)}},[userId,enabled,online]);
 useEffect(()=>{runner.current?.changed()},[changeKey]);
}
