'use client';
import {useState} from 'react';
import Link from 'next/link';
import {loadLedger,localAccount} from '@/lib/storage';
import {supabase} from '@/lib/supabase';
import {validateLedger,type Ledger} from '@/lib/model';
export default function Recovery(){
 const [data,setData]=useState<Ledger|null>(null),[owner,setOwner]=useState(''),[message,setMessage]=useState(''),[busy,setBusy]=useState(false);
 async function inspect(){setBusy(true);setMessage('');try{
  const session=supabase?(await supabase.auth.getSession()).data.session:null;
  const cached=await localAccount();
  const uid=session?.user.id||cached?.uid;
  if(!uid){setMessage('افتح هذه الصفحة من المتصفح الذي كنت تستخدمه مع النسخة القديمة، أو سجل دخول النسخة القديمة أولًا.');return}
  const ledger=await loadLedger(uid);
  if(!ledger||!validateLedger(ledger)){setMessage('لا توجد نسخة محلية صالحة لهذا الحساب على هذا المتصفح. لم يتم حذف أو تغيير أي بيانات.');return}
  setData(ledger);setOwner(uid);setMessage('تم العثور على البيانات محليًا. صدّرها واحتفظ بالملف قبل الاستيراد.');
 }catch{setMessage('تعذر قراءة التخزين المحلي. لم يتم تغيير أي بيانات.');}finally{setBusy(false)}}
 async function download(){if(!data)return;const file=new Blob([JSON.stringify({application:'ElNota',owner_id:owner,exportedAt:new Date().toISOString(),data},null,2)],{type:'application/json'});const url=URL.createObjectURL(file);const a=document.createElement('a');a.href=url;a.download=`elnota-legacy-${new Date().toISOString().slice(0,10)}.json`;a.click();setTimeout(()=>URL.revokeObjectURL(url),10000)}
 return <main className="container section" style={{maxWidth:780}}><h1>استرجاع بيانات النسخة السابقة</h1><p>هذه الصفحة تقرأ دفتر حسابك القديم من نفس المتصفح دون حذفه أو تغييره، ولا ترفع بياناته إلى السيرفر.</p><ol><li>افتح هذه الصفحة على الجهاز والمتصفح القديمين.</li><li>ابحث عن بيانات الحساب وصدّر الملف.</li><li>افتح التطبيق الجديد، ثم الإعدادات ← استيراد نسخة قديمة أو جديدة.</li><li>راجع السجلات وصافي الأرصدة قبل الموافقة. الاستيراد إلى دفتر فارغ فقط.</li></ol><button className="button" onClick={inspect} disabled={busy}>{busy?'جارٍ الفحص…':'البحث عن بياناتي القديمة'}</button>{message&&<p role="status" style={{marginTop:20}}>{message}</p>}{data&&<section className="price-card"><h2>البيانات الموجودة</h2><p>{data.customers.length} عميل · {data.invoices.length} فاتورة · {data.products.length} منتج</p><button className="button" onClick={download}>تنزيل ملف الاستيراد</button></section>}<p style={{marginTop:24}}>لو لديك ملف نسخة احتياطية قديم بالفعل، يمكنك استيراده مباشرة من إعدادات التطبيق الجديد. لا تمسح بيانات المتصفح أو تحذف التطبيق القديم قبل التحقق من النقل.</p><div className="hero-actions"><Link href="/app/" className="button">فتح التطبيق الجديد</Link><Link href="/dashboard" className="button secondary">فتح الدفتر القديم</Link></div></main>
}
