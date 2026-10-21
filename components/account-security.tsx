'use client';
import {useRef,useState} from 'react';
import {KeyRound} from 'lucide-react';
import {supabase} from '@/lib/supabase';
import type {Account} from '@/lib/model';
export function AccountSecurity({account,userId,online}:{account:Account|null;userId:string;online:boolean}){
 const [busy,setBusy]=useState(false),[message,setMessage]=useState(''),[error,setError]=useState('');const submitting=useRef(false);
 async function change(e:React.FormEvent<HTMLFormElement>){e.preventDefault();if(submitting.current)return;const form=e.currentTarget;const data=new FormData(form);const current=String(data.get('current_password')??''),password=String(data.get('password')??'');setMessage('');setError('');
 if(password!==String(data.get('confirm_password')??'')){setError('تأكيد كلمة المرور غير مطابق.');return}
 if(password.length<8||password.length>128){setError('كلمة المرور من 8 إلى 128 حرفًا.');return}
 if(password===current){setError('اختار كلمة مرور مختلفة عن الحالية.');return}
 if(!supabase||!online){setError('اتصل بالإنترنت لتغيير كلمة المرور.');return}
 submitting.current=true;setBusy(true);
 try{const {data:identity,error:identityError}=await supabase.auth.getUser();if(identityError||!identity.user?.email||identity.user.id!==userId)throw Error('SESSION_REQUIRED');
 const {data:verified,error:verifyError}=await supabase.auth.signInWithPassword({email:identity.user.email,password:current});if(verifyError||verified.user?.id!==userId)throw Error('CURRENT_PASSWORD_INVALID');
 const {error:updateError}=await supabase.auth.updateUser({password});if(updateError)throw updateError;form.reset();setMessage('تم تغيير كلمة المرور. استخدم نفس الإيميل وكلمة المرور الجديدة للدخول.');
 }catch(e){const msg=(e as Error).message;setError(msg==='CURRENT_PASSWORD_INVALID'?'كلمة المرور الحالية غير صحيحة.':msg==='SESSION_REQUIRED'?'سجّل دخولك بنفس الحساب أولًا.':msg.toLowerCase().includes('same')?'اختار كلمة مرور مختلفة.':'تعذر تغيير كلمة المرور. جرّب مرة تانية أو اطلب من الإدارة تغييرها.')}finally{submitting.current=false;setBusy(false)}
 }
 return <details className="panel settings-section settings-security" open><summary><KeyRound size={18}/><span>حساب الدخول وكلمة المرور<small>تغيير مباشر بدون رسالة تأكيد أو OTP</small></span></summary><div className="settings-section-body"><label>إيميل الحساب المفعّل<input type="email" dir="ltr" readOnly value={account?.email??''} autoComplete="username"/></label><p className="muted">سجّل دخولك بهذا الإيميل على أجهزتك عشان تفتح نفس الحساب والتفعيل. لو ناسي كلمة المرور الحالية، اطلب من الإدارة تغييرها.</p><form onSubmit={change}><label>كلمة المرور الحالية<input name="current_password" type="password" dir="ltr" autoComplete="current-password" required maxLength={128}/></label><div className="settings-form-row"><label>كلمة المرور الجديدة<input name="password" type="password" dir="ltr" autoComplete="new-password" required minLength={8} maxLength={128}/></label><label>تأكيد كلمة المرور الجديدة<input name="confirm_password" type="password" dir="ltr" autoComplete="new-password" required minLength={8} maxLength={128}/></label></div><button className="button small" disabled={busy||!online||!account}>{busy?'جارٍ الحفظ…':'تغيير كلمة المرور'}</button></form>{message&&<p role="status" className="notice success">{message}</p>}{error&&<p role="alert" className="notice error">{error}</p>}</div></details>
}
