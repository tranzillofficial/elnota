import { readdir,writeFile } from 'node:fs/promises';
const files=await readdir('.next/static',{recursive:true});
const assets=files.filter(p=>/\.(js|css|woff2?)$/.test(p)).map(p=>'/_next/static/'+p.replaceAll('\\','/'));
if(!assets.length)throw new Error('No offline assets generated');
await writeFile('public/offline-assets.json',JSON.stringify(assets));
console.log(`Prepared ${assets.length} offline assets`);
