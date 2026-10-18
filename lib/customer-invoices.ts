import {type Customer,type Invoice,total,paid,remaining,overdueAmount} from './model.ts';
export function customerInvoiceGroups(customers:Customer[],invoices:Invoice[],search='',filter='all'){
 const query=search.trim().toLocaleLowerCase();return customers.flatMap(customer=>{const all=invoices.filter(i=>i.customerId===customer.id);if(!all.length)return [];const active=all.filter(i=>!i.voided);const due=active.reduce((sum,i)=>sum+remaining(i),0);const late=active.reduce((sum,i)=>sum+overdueAmount(i),0);if(query&&!customer.name.toLocaleLowerCase().includes(query)&&!customer.phone.includes(query)&&!all.some(i=>i.number.toLocaleLowerCase().includes(query)))return [];if(filter==='unpaid'&&due<=0||filter==='paid'&&(!active.length||due>0)||filter==='late'&&late<=0)return [];return [{customer,count:all.length,total:active.reduce((sum,i)=>sum+total(i),0),paid:active.reduce((sum,i)=>sum+paid(i),0),remaining:due,late,voidedOnly:!active.length}];});
}
/** A platform name is not a merchant name. Ask for the store instead of guessing. */
export function invoiceBusinessName(name:string){const clean=name.trim();return !clean||/^(redom\s*labs?|ريدوم\s*لابز?|ريدوم)$/i.test(clean)?null:clean;}
