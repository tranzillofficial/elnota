'use client';
import {useEffect,useState} from 'react';
import {cloudStatus} from '@/lib/cloud-subscription';
export function CloudRenewal({until}:{until:string|null|undefined}){const [now,setNow]=useState(Date.now);useEffect(()=>{const timer=setInterval(()=>setNow(Date.now()),60000);return()=>clearInterval(timer)},[]);const state=cloudStatus(until,now);return state.expiring?<div className="notice" role="alert">اشتراك الكلاود ينتهي خلال {state.days} يوم، بتاريخ {new Date(until!).toLocaleDateString('ar-EG')}. جدّد الاشتراك للحفاظ على النسخ التلقائي.</div>:state.expired?<div className="notice" role="status">انتهى اشتراك الكلاود. بيانات الجهاز محفوظة؛ جدّد الاشتراك لاستئناف النسخ السحابي.</div>:null;}
