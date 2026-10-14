import { type Ledger,type Product,validateLedger } from './model.ts';

export type CatalogImport={id:string;payload:{categories:string[];products:Product[];fourFieldCatalog:boolean;categoryMap?:Record<string,string>}};
function remapCategories(ledger:Ledger,map:Record<string,string>):Ledger {
 if(!map||typeof map!=='object'||Array.isArray(map)||Object.values(map).some(v=>typeof v!=='string'||!v.trim()))throw new Error('أسماء الأقسام غير صالحة');
 const category=(name:string)=>Object.hasOwn(map,name)?map[name]:name;
 const products=ledger.products.map(p=>p.category&&category(p.category)!==p.category?{...p,category:category(p.category)}:p);
 const categories=[...new Set((ledger.categories||[]).map(category))];
 if(products.every((p,i)=>p===ledger.products[i])&&categories.length===(ledger.categories||[]).length&&categories.every((c,i)=>c===ledger.categories?.[i]))return ledger;
 return {...ledger,products,categories,updatedAt:new Date().toISOString()};
}
// Import markers travel with backups. Reopening never replaces local edits or archived items.
export function mergeCatalogImports(ledger:Ledger,imports:CatalogImport[]):Ledger {
 let next=ledger;
 for(const source of imports){
  const payload=source.payload;
  // Older clients may have marked an import before understanding its category mapping.
  if(next.catalogImports?.includes(source.id)){if(payload?.categoryMap)next=remapCategories(next,payload.categoryMap);continue;}
  if(!payload||!Array.isArray(payload.categories)||!Array.isArray(payload.products)||payload.fourFieldCatalog!==true)throw new Error('بيانات استيراد الأصناف غير صالحة');
  const ids=new Set(next.products.map(p=>p.id));
  const candidate=remapCategories({...next,products:[...next.products,...payload.products.filter(p=>!ids.has(p.id)).map(({image,...p})=>p)],categories:[...new Set([...(next.categories||[]),...payload.categories])],fourFieldCatalog:true,catalogImports:[...(next.catalogImports||[]),source.id],updatedAt:new Date().toISOString()},payload.categoryMap||{});
  if(!validateLedger(candidate))throw new Error('بيانات استيراد الأصناف غير صالحة');
  next=candidate;
 }
 return next;
}
