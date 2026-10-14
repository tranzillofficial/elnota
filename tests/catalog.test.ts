import test from 'node:test';
import assert from 'node:assert/strict';
import { emptyLedger,validateLedger } from '../lib/model.ts';
import { mergeCatalogImports,type CatalogImport } from '../lib/catalog.ts';
test('category changes migrate already imported local products without replacing prices, IDs or invoices',()=>{
 const l=emptyLedger();l.catalogImports=['original'];l.categories=['اطفال','طقم','ك','شاشات','حافظة','بوتاجازات وافران','ثلاجات وفريزر','فوط0'];l.products=[{id:'edited',name:'صنف معدل',price:999,barcode:'',category:'اطفال',boxQuantity:6,archived:true},{id:'screen',name:'صنف',price:40,barcode:'',category:'شاشات'}];
 const change:CatalogImport={id:'change',payload:{products:[],categories:[],fourFieldCatalog:true,categoryMap:{'اطفال':'طقم','ك':'كوفرته','شاشات':'حافظات','حافظة':'حافظات','بوتاجازات وافران':'كسوه انتريه','ثلاجات وفريزر':'فوط','فوط0':'فوط'}}};
 const result=mergeCatalogImports(l,[change]);assert.deepEqual(result.categories,['طقم','كوفرته','حافظات','كسوه انتريه','فوط']);assert.equal(result.products.length,2);assert.deepEqual(result.products[0],{...l.products[0],category:'طقم'});assert.equal(result.products[1].category,'حافظات');assert.deepEqual(result.invoices,l.invoices);assert.equal(mergeCatalogImports(result,[change]),result);
 const oldClient={...l,catalogImports:['original','change']};assert.deepEqual(mergeCatalogImports(oldClient,[change]).categories,result.categories);assert.equal(mergeCatalogImports(oldClient,[change]).products[0].category,'طقم');
});
const source:CatalogImport={id:'catalog-v1',payload:{categories:['قسم','قسم فارغ'],fourFieldCatalog:true,products:[{id:'import-1',name:'صنف',barcode:'',category:'قسم',itemNumber:'001',boxQuantity:1,price:100}]}};
test('imports retain existing customers, invoices and products; no account dataset means no change',()=>{
 const ledger=emptyLedger();ledger.products=[{id:'existing',name:'قديم',price:5,barcode:''}];
 assert.equal(mergeCatalogImports(ledger,[]),ledger);
 const merged=mergeCatalogImports(ledger,[source]);
 assert.equal(merged.products.length,2);assert.deepEqual(merged.categories,['قسم','قسم فارغ']);assert.equal(merged.products[1].itemNumber,'001');assert.equal(validateLedger(merged),true);assert.deepEqual(merged.customers,ledger.customers);assert.deepEqual(merged.invoices,ledger.invoices);
});
test('reopening and backup restoration preserve local edits and archiving without duplicate imports',()=>{
 const merged=mergeCatalogImports(emptyLedger(),[source]);merged.products[0].price=200;merged.products[0].archived=true;
 const backup=JSON.parse(JSON.stringify(merged));const reopened=mergeCatalogImports(backup,[source]);
 assert.equal(reopened,backup);assert.equal(reopened.products.length,1);assert.equal(reopened.products[0].price,200);assert.equal(reopened.products[0].archived,true);
});
test('missing prices and quantities remain distinct from zero; malformed quantities are rejected',()=>{
 const importRow:CatalogImport={...source,payload:{...source.payload,products:[{id:'missing',name:'ناقص',barcode:'',price:0,priceMissing:true}]}};
 const merged=mergeCatalogImports(emptyLedger(),[importRow]);assert.equal(merged.products[0].boxQuantity,undefined);assert.equal(merged.products[0].priceMissing,true);
 assert.throws(()=>mergeCatalogImports(emptyLedger(),[{...source,payload:{...source.payload,products:[{...source.payload.products[0],boxQuantity:-1}]}}]));
});
