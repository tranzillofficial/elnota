import { type Invoice,type Ledger,money,total,paid,remaining,installmentSchedule } from './model';
/** Render exact ledger amounts locally; no invoice/customer data leaves the device. */
export async function createInvoiceImage(invoice:Invoice,ledger:Ledger):Promise<File>{
 await document.fonts.ready;
 const canvas=document.createElement('canvas');canvas.width=1000;
 const ctx=canvas.getContext('2d');if(!ctx)throw new Error('تعذر تجهيز الصورة');
 const commands:(()=>void)[]=[];let y=58;
 const font=(size:number,bold=false)=>`${bold?600:400} ${size}px "IBM Plex Sans Arabic", Tahoma, Arial, sans-serif`;
 function wrap(text:string,width:number,size:number){ctx!.font=font(size);const lines:string[]=[];for(const paragraph of String(text).split('\n')){let line='';for(const word of paragraph.split(/\s+/)){const candidate=line?line+' '+word:word;if(ctx!.measureText(candidate).width<=width){line=candidate;continue}if(line)lines.push(line);line='';for(const char of word){if(ctx!.measureText(line+char).width>width&&line){lines.push(line);line=''}line+=char}}lines.push(line)}return lines}
 function text(value:string,x:number,width:number,size=26,bold=false,color='#243f32',align:CanvasTextAlign='right'){const lines=wrap(value,width,size),top=y;commands.push(()=>{ctx!.font=font(size,bold);ctx!.fillStyle=color;ctx!.textAlign=align;ctx!.direction='rtl';ctx!.textBaseline='top';lines.forEach((line,i)=>ctx!.fillText(line,x,top+i*(size+13)))});y+=lines.length*(size+13)}
 function rule(){const at=y;commands.push(()=>{ctx!.strokeStyle='#dfebe3';ctx!.lineWidth=2;ctx!.beginPath();ctx!.moveTo(58,at);ctx!.lineTo(942,at);ctx!.stroke()});y+=24}
 function row(values:string[],height:number,header=false,scheduleRow=false){const at=y;commands.push(()=>{if(header){ctx!.fillStyle='#e9f7ef';ctx!.fillRect(58,at,884,height)}ctx!.direction='rtl';ctx!.textBaseline='top';ctx!.font=font(25,header);ctx!.fillStyle='#244735';ctx!.textAlign='right';const widths=scheduleRow?[300,100,250,150]:[395,105,135,145],xs=scheduleRow?[924,680,640,204]:[924,490,355,204];values.forEach((v,i)=>wrap(v,widths[i],25).forEach((line,j)=>ctx!.fillText(line,xs[i],at+16+j*38)));ctx!.strokeStyle='#e4ece7';ctx!.beginPath();ctx!.moveTo(58,at+height);ctx!.lineTo(942,at+height);ctx!.stroke()});y+=height}
 function pair(label:string,value:string,bold=false){const at=y;commands.push(()=>{ctx!.font=font(27,bold);ctx!.direction='rtl';ctx!.textBaseline='top';ctx!.textAlign='right';ctx!.fillStyle=bold?'#087b53':'#486554';ctx!.fillText(label,924,at);ctx!.textAlign='left';ctx!.fillText(value,76,at)});y+=49}
 const customer=ledger.customers.find(c=>c.id===invoice.customerId);
 text(ledger.settings.businessName,500,880,42,true,'#087b53','center');y+=7;text('فاتورة '+invoice.number,500,880,27,true,'#244735','center');text('التاريخ: '+invoice.date,500,880,24,false,'#6a7d71','center');y+=12;rule();
 text('العميل: '+(customer?.name||''),942,880,29,true);if(customer?.phone)text('رقم الهاتف: '+customer.phone,942,880,24);if(ledger.settings.phone)text('تواصل المتجر: '+ledger.settings.phone,942,880,24);if(ledger.settings.address)text(ledger.settings.address,942,880,24);text('طريقة الدفع: '+({cash:'نقدي',credit:'آجل',installment:'أقساط'}[invoice.method]),942,880,25,true);if(invoice.voided)text('فاتورة ملغاة',942,880,29,true,'#c93949');y+=16;
 if(invoice.entryMode==='amount'){text(invoice.lines[0].name,942,880,29,true);pair('قيمة المبلغ',money(total(invoice))+' '+ledger.settings.currency,true)}else{
 row(['المنتج','الكمية','سعر الوحدة','الإجمالي'],64,true);
 for(const line of invoice.lines){const height=Math.max(70,wrap(line.name,395,25).length*38+32);row([line.name,String(line.quantity),money(line.price),money(line.price*line.quantity)],height)}}
 y+=26;pair('الإجمالي',money(total(invoice))+' '+ledger.settings.currency,true);pair('المدفوع',money(paid(invoice))+' '+ledger.settings.currency);pair('المتبقي',money(remaining(invoice))+' '+ledger.settings.currency,true);y+=12;rule();
 const schedule=installmentSchedule(invoice);if(schedule.length){text('جدول الأقساط — '+schedule.length+' شهر',942,880,29,true);text('أول استحقاق: '+schedule[0].date,942,880,25);y+=8;row(['القسط','', 'الاستحقاق','القيمة'],64,true,true);for(const entry of schedule)row(['القسط '+entry.number,'',entry.date,money(entry.amount)+' جنيه'],70,false,true);y+=22;rule()}else if(invoice.method==='installment'&&invoice.dueDate)text('أول استحقاق: '+invoice.dueDate,942,880,25);
 if(invoice.notes){text('ملاحظات',942,880,27,true);text(invoice.notes,942,880,24);y+=15}
 if(invoice.payments.length){text('سجل الدفعات',942,880,27,true);for(const p of invoice.payments)text(`${p.date} — ${money(p.amount)} جنيه${p.note?' — '+p.note:''}`,942,880,24);y+=15}
 text('تم إصدارها من النوتة · ElNota',500,880,23,false,'#6a7d71','center');
 if(y>30000)throw new Error('الفاتورة طويلة جدًا للصورة. استخدم طباعة / PDF لهذه الفاتورة.');canvas.height=Math.ceil(y+50);ctx.fillStyle='white';ctx.fillRect(0,0,canvas.width,canvas.height);commands.forEach(command=>command());
 const blob=await new Promise<Blob>((resolve,reject)=>canvas.toBlob(b=>b?resolve(b):reject(new Error('تعذر حفظ صورة الفاتورة')),'image/png'));
 return new File([blob],`ElNota-${invoice.number.replace(/[^a-zA-Z0-9_-]/g,'')}.png`,{type:'image/png'});
}
