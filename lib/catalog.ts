import { type Ledger,type Product,validateLedger } from './model.ts';

export type CatalogImport={id:string;payload:{categories:string[];products:Product[];fourFieldCatalog:boolean}};
// Import markers travel with backups. Reopening never replaces local edits or archived items.
export function mergeCatalogImports(ledger:Ledger,imports:CatalogImport[]):Ledger {
 let next=ledger;
 for(const source of imports){
  if(next.catalogImports?.includes(source.id))continue;
  const payload=source.payload;
  if(!payload||!Array.isArray(payload.categories)||!Array.isArray(payload.products)||payload.fourFieldCatalog!==true)throw new Error('بيانات استيراد الأصناف غير صالحة');
  const ids=new Set(next.products.map(p=>p.id));
  const candidate:Ledger={...next,products:[...next.products,...payload.products.filter(p=>!ids.has(p.id)).map(({image,...p})=>p)],categories:[...new Set([...(next.categories||[]),...payload.categories])],fourFieldCatalog:true,catalogImports:[...(next.catalogImports||[]),source.id],updatedAt:new Date().toISOString()};
  if(!validateLedger(candidate))throw new Error('بيانات استيراد الأصناف غير صالحة');
  next=candidate;
 }
 return next;
}
