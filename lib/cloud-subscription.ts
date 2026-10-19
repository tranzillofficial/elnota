export const BACKUP_INTERVAL=24*60*60*1000;
export function cloudStatus(until:string|null|undefined,now=Date.now()){
 const end=until?Date.parse(until):NaN;const active=Number.isFinite(end)&&end>now;
 return {active,expiring:active&&end-now<=5*BACKUP_INTERVAL,expired:Number.isFinite(end)&&end<=now,days:active?Math.ceil((end-now)/BACKUP_INTERVAL):0};
}
export function backupDue(last:string|null|undefined,now=Date.now()){const time=last?Date.parse(last):NaN;return !Number.isFinite(time)||backupDay(time)<backupDay(now);}
// Calendar days follow Egypt's IANA timezone, including DST changes.
export function backupDay(now=Date.now()){
 const parts=new Intl.DateTimeFormat('en-CA',{timeZone:'Africa/Cairo',year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(now);
 return ['year','month','day'].map(k=>parts.find(p=>p.type===k)!.value).join('-');
}
export function backupCheckDelay(now=Date.now()){return Math.max(50,60000-now%60000);}
export type DeviceBackupInfo={id:string;backup_day:string;captured_at:string;uploaded_at:string;size_bytes:number};
