import { type Ledger } from './model.ts';
export type SyncBaseline={revision:number;fingerprint:string;at:string};
export type SyncChoice='auto'|'local'|'cloud';
export type SyncConflict={local:{customers:number;products:number;invoices:number};cloud:{customers:number;products:number;invoices:number};revision:number};
export function counts(ledger:Ledger){return {customers:ledger.customers.length,products:ledger.products.length,invoices:ledger.invoices.length}}
function canonical(value:unknown):unknown {if(Array.isArray(value))return value.map(canonical);if(value&&typeof value==='object')return Object.fromEntries(Object.entries(value).filter(([,v])=>v!==undefined).sort(([a],[b])=>a.localeCompare(b,'en')).map(([k,v])=>[k,canonical(v)]));return value}
export async function ledgerFingerprint(ledger:Ledger){const value={...ledger,updatedAt:undefined,products:ledger.products.map(({image,...p})=>p)};const digest=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(JSON.stringify(canonical(value))));return Array.from(new Uint8Array(digest),n=>n.toString(16).padStart(2,'0')).join('')}
export function syncPlan({local,remote,remoteRevision,baseline,knownRevision,pristine}:{local:string;remote:string|null;remoteRevision:number;baseline?:SyncBaseline;knownRevision:number;pristine:boolean}):'push'|'pull'|'same'|'conflict'{
 if(remote===null)return baseline&&local===baseline.fingerprint?'conflict':'push';
 if(local===remote)return 'same';
 if(!baseline){if(pristine)return 'pull';return knownRevision>0&&knownRevision===remoteRevision?'push':'conflict'}
 const localChanged=local!==baseline.fingerprint;const remoteChanged=remote!==baseline.fingerprint||remoteRevision!==baseline.revision;
 if(localChanged&&remoteChanged)return 'conflict';return localChanged?'push':'pull';
}
export function isPristine(ledger:Ledger){return !ledger.customers.length&&!ledger.products.length&&!ledger.invoices.length&&!ledger.categories?.length&&!ledger.settings.phone&&!ledger.settings.address}
export function withLocalImages(remote:Ledger,local:Ledger):Ledger {const images=new Map(local.products.filter(p=>p.image).map(p=>[p.id,p.image]));return {...remote,products:remote.products.map(p=>images.has(p.id)?{...p,image:images.get(p.id)}:p)}}
