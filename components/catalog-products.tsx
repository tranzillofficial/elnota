'use client';
import { useState } from 'react';
import { Pencil,Archive,Save } from 'lucide-react';
import { type Ledger,type Product,id,money } from '@/lib/model';

export function CatalogProductForm({product,categories,onSave,onCancel}:{product?:Product;categories:string[];onSave:(p:Product)=>Promise<void>;onCancel:()=>void}){
 const [busy,setBusy]=useState(false);const [error,setError]=useState('');
 return <form className="panel form-panel" onSubmit={async e=>{e.preventDefault();const f=new FormData(e.currentTarget);setBusy(true);setError('');try{const raw=String(f.get('quantity')).trim();const q=raw===''?undefined:Number(raw);const priceRaw=String(f.get('price')).trim();await onSave({...product,id:product?.id||id(),name:String(f.get('name')).trim(),barcode:product?.barcode||'',category:String(f.get('category')),itemNumber:String(f.get('itemNumber')).trim(),boxQuantity:q===0?1:q,price:priceRaw===''?0:Number(priceRaw),priceMissing:priceRaw==='',image:undefined,archived:false})}catch(e){setError((e as Error).message)}finally{setBusy(false)}}}>
 <h2>{product?'تعديل الصنف':'إضافة صنف'}</h2>
 <label>القسم<select name="category" defaultValue={product?.category||categories[0]||''}><option value="">بدون قسم</option>{categories.map(c=><option key={c}>{c}</option>)}</select></label>
 <label>الاسم<input name="name" required maxLength={150} defaultValue={product?.name}/></label>
 <label>الكميه<input name="quantity" type="number" min="0" step="1" defaultValue={product?.boxQuantity} placeholder="غير محددة"/><small className="muted">عدد القطع في العلبة. إدخال 0 يعني قطعة واحدة.</small></label>
 <label>رقم الصنف<input name="itemNumber" defaultValue={product?.itemNumber} maxLength={100}/></label>
 <label>السعر<input name="price" type="number" min="0" step="0.01" defaultValue={product?.priceMissing?undefined:product?.price} placeholder="غير محدد"/></label>
 {error&&<p role="alert" className="notice error">{error}</p>}<div className="form-actions"><button className="button" disabled={busy}><Save size={18}/>{busy?'جارٍ الحفظ…':'حفظ الصنف'}</button><button type="button" className="button secondary" onClick={onCancel}>إلغاء</button></div></form>;
}

export function CatalogProducts({ledger,search,onEdit,onArchive}:{ledger:Ledger;search:string;onEdit:(p:Product)=>void;onArchive:(p:Product)=>void}){
 const [category,setCategory]=useState('');const [page,setPage]=useState(0);
 const categories=[...new Set([...(ledger.categories||[]),...ledger.products.map(p=>p.category).filter((c):c is string=>Boolean(c))])];
 const matches=ledger.products.filter(p=>!p.archived&&(!category||p.category===category)&&(!search||p.name.includes(search)||p.itemNumber?.includes(search)||p.barcode.includes(search)));
 // Clamp when search or archived rows shrink the result set.
 const current=Math.min(page,Math.max(0,Math.ceil(matches.length/50)-1));
 return <section className="panel catalog-panel"><div className="catalog-categories" aria-label="الأقسام"><button className={!category?'active':''} onClick={()=>{setCategory('');setPage(0)}}>كل الأقسام</button>{categories.map(c=><button key={c} className={category===c?'active':''} onClick={()=>{setCategory(c);setPage(0)}}>{c}<small>{ledger.products.filter(p=>!p.archived&&p.category===c).length}</small></button>)}</div><div className="panel-heading"><h2>{category||'كل الأصناف'}</h2><span>{matches.length} صنف</span></div>
 <div className="catalog-table-scroll"><table className="catalog-table"><thead><tr><th>الاسم</th><th>الكميه</th><th>رقم الصنف</th><th>السعر</th><th aria-label="إجراءات"/></tr></thead><tbody>{matches.slice(current*50,current*50+50).map(p=><tr key={p.id}><td><strong>{p.name}</strong>{!category&&<small>{p.category}</small>}</td><td>{p.boxQuantity??'غير محددة'}</td><td>{p.itemNumber||'—'}</td><td>{p.priceMissing?<span className="muted">غير محدد</span>:money(p.price)+' جنيه'}</td><td><div className="catalog-row-actions"><button className="icon-button" aria-label={'تعديل '+p.name} onClick={()=>onEdit(p)}><Pencil size={17}/></button><button className="icon-button danger" aria-label={'أرشفة '+p.name} onClick={()=>onArchive(p)}><Archive size={17}/></button></div></td></tr>)}</tbody></table></div>
 {!matches.length&&<p className="empty-text">لا توجد أصناف في هذا القسم حاليًا.</p>}{matches.length>50&&<div className="catalog-pagination"><button className="button secondary small" disabled={current===0} onClick={()=>setPage(current-1)}>السابق</button><span>{current+1} / {Math.ceil(matches.length/50)}</span><button className="button secondary small" disabled={(current+1)*50>=matches.length} onClick={()=>setPage(current+1)}>التالي</button></div>}</section>;
}
