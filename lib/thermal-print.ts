import {invoiceBusinessName} from './customer-invoices.ts';
import {type Invoice,type Ledger,money,total,paid,remaining,customerTotals,installmentSchedule} from './model.ts';
export function rasterStripe(rgba:Uint8ClampedArray,width:number,height:number):Uint8Array {
 if(width%8||rgba.length!==width*height*4||width<8||height<1||height>256)throw new Error('Invalid raster size');
 const bytes=width/8;const data=new Uint8Array(8+bytes*height);data.set([29,118,48,0,bytes&255,bytes>>8,height&255,height>>8]);
 for(let y=0;y<height;y++)for(let x=0;x<width;x++){const p=(y*width+x)*4;const alpha=rgba[p+3]/255;const light=(rgba[p]*.299+rgba[p+1]*.587+rgba[p+2]*.114)*alpha+255*(1-alpha);if(light<165)data[8+y*bytes+(x>>3)]|=128>>(x%8)}
 return data;
}
export async function thermalReceipt(invoice:Invoice,ledger:Ledger,width:384|576){
 if(!invoiceBusinessName(ledger.settings.businessName))throw new Error('حدد اسم المتجر من بيانات النشاط أولًا.');
 await document.fonts.ready;const canvas=document.createElement('canvas');canvas.width=width;const ctx=canvas.getContext('2d');if(!ctx)throw new Error('تعذر تجهيز الفاتورة');
 const rows:{text:string;bold:boolean}[]=[];const size=width===384?22:26;
 function line(value:string,bold=false){ctx!.font=`${bold?'bold ':''}${size}px Tahoma, Arial, sans-serif`;for(const paragraph of value.split('\n')){let row='';for(const char of paragraph){if(ctx!.measureText(row+char).width>width-24){rows.push({text:row,bold});row=''}row+=char}rows.push({text:row,bold})}}
 const customer=ledger.customers.find(c=>c.id===invoice.customerId);
 line(ledger.settings.businessName,true);if(ledger.settings.phone)line(ledger.settings.phone);if(ledger.settings.address)line(ledger.settings.address);line('فاتورة '+invoice.number,true);line(invoice.date);line('العميل: '+(customer?.name||''));if(customer?.phone)line(customer.phone);if(invoice.voided)line('فاتورة ملغاة',true);
 for(const item of invoice.lines){line(item.name,true);line(`${money(item.quantity)} × ${money(item.price)} = ${money(item.quantity*item.price)} ${ledger.settings.currency}`)}
 line('الإجمالي: '+money(total(invoice))+' '+ledger.settings.currency,true);line('المدفوع بالفاتورة: '+money(paid(invoice)));line('المتبقي على حساب العميل: '+money(customerTotals(ledger,invoice.customerId).remaining),true);
 for(const entry of installmentSchedule(invoice))line(`قسط ${entry.number} · ${entry.date} · ${money(entry.amount)}`);
 if(invoice.notes)line(invoice.notes);for(const payment of invoice.payments)line(`${payment.date} · ${money(payment.amount)} · ${payment.note}`);line('النوتة · ElNota');
 const height=rows.length*(size+12)+28;if(height>60000)throw new Error('الفاتورة طويلة جدًا للطباعة المباشرة. استخدم طباعة النظام.');canvas.height=height;ctx.fillStyle='white';ctx.fillRect(0,0,width,height);ctx.direction='rtl';ctx.textAlign='right';ctx.textBaseline='top';ctx.fillStyle='black';rows.forEach((row,i)=>{ctx.font=`${row.bold?'bold ':''}${size}px Tahoma, Arial, sans-serif`;ctx.fillText(row.text,width-12,14+i*(size+12))});
 const stripes:Uint8Array[]=[new Uint8Array([27,64])];for(let y=0;y<height;y+=128){const h=Math.min(128,height-y);stripes.push(rasterStripe(ctx.getImageData(0,y,width,h).data,width,h))}stripes.push(new Uint8Array([27,100,4]));return stripes;
}
export type PrintCharacteristic={properties:{write:boolean;writeWithoutResponse:boolean};writeValueWithResponse:(v:Uint8Array<ArrayBuffer>)=>Promise<void>;writeValueWithoutResponse:(v:Uint8Array<ArrayBuffer>)=>Promise<void>};
type Server={connected:boolean;connect:()=>Promise<Server>;disconnect:()=>void;getPrimaryServices:()=>Promise<{getCharacteristics:()=>Promise<PrintCharacteristic[]>}[]>};
export type PrinterDevice={name?:string;gatt?:Server};
export function selectPrinter():Promise<PrinterDevice>{const bluetooth=(navigator as Navigator&{bluetooth?:{requestDevice:(options:unknown)=>Promise<PrinterDevice>}}).bluetooth;if(!bluetooth)throw new Error('الاتصال المباشر يحتاج Chrome على Android أو متصفح يدعم Web Bluetooth. استخدم طباعة النظام لهذا الجهاز.');return bluetooth.requestDevice({acceptAllDevices:true,optionalServices:[0xff00,0xffe0,0x18f0,0xae30]})}
export async function connectPrinter(device:PrinterDevice){if(!device.gatt)throw new Error('الطابعة لا تدعم BLE');const server=await device.gatt.connect();for(const service of await server.getPrimaryServices()){const characteristic=(await service.getCharacteristics()).find(c=>c.properties.write||c.properties.writeWithoutResponse);if(characteristic)return {server,characteristic}}server.disconnect();throw new Error('لم يتم العثور على منفذ طباعة متوافق. استخدم خدمة طباعة النظام للطابعة.');}
export async function sendThermal(characteristic:PrintCharacteristic,stripes:Uint8Array[]){for(const stripe of stripes)for(let at=0;at<stripe.length;at+=20){const chunk=new Uint8Array(stripe.slice(at,at+20));if(characteristic.properties.write)await characteristic.writeValueWithResponse(chunk);else{await characteristic.writeValueWithoutResponse(chunk);await new Promise(resolve=>setTimeout(resolve,25))}}}
