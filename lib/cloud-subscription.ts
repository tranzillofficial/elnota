export const BACKUP_INTERVAL=24*60*60*1000;
export function cloudStatus(until:string|null|undefined,now=Date.now()){
 const end=until?Date.parse(until):NaN;const active=Number.isFinite(end)&&end>now;
 return {active,expiring:active&&end-now<=5*BACKUP_INTERVAL,expired:Number.isFinite(end)&&end<=now,days:active?Math.ceil((end-now)/BACKUP_INTERVAL):0};
}
export function backupDue(last:string|null|undefined,now=Date.now()){const time=last?Date.parse(last):NaN;return !Number.isFinite(time)||now-time>=BACKUP_INTERVAL;}
