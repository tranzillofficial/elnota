import test from 'node:test';
import assert from 'node:assert/strict';
import {cloudStatus,backupDue,backupDay,backupCheckDelay,BACKUP_INTERVAL} from '../lib/cloud-subscription.ts';
test('renewal alert starts exactly five days before expiry for monthly or yearly subscriptions',()=>{const now=Date.parse('2026-10-18T00:00:00Z');assert.equal(cloudStatus(new Date(now+5*BACKUP_INTERVAL+1).toISOString(),now).expiring,false);assert.deepEqual(cloudStatus(new Date(now+5*BACKUP_INTERVAL).toISOString(),now),{active:true,expiring:true,expired:false,days:5});assert.equal(cloudStatus(new Date(now+1).toISOString(),now).days,1);assert.equal(cloudStatus(new Date(now).toISOString(),now).expired,true);assert.equal(cloudStatus(null,now).active,false)});
test('backup becomes due at Cairo midnight, not 24 hours after a previous upload',()=>{
 const before=Date.parse('2026-10-18T20:59:59.999Z'), midnight=before+1;
 assert.equal(backupDay(before),'2026-10-18');assert.equal(backupDay(midnight),'2026-10-19');
 assert.equal(backupDue('2026-10-18T20:55:00Z',before),false);
 assert.equal(backupDue('2026-10-18T20:55:00Z',midnight),true);
 assert.equal(backupDue(null,midnight),true);assert.equal(backupDue('invalid',midnight),true);
 assert.equal(backupDue('2026-10-16T18:00:00Z',midnight),true);
 assert.equal(backupCheckDelay(before),50);assert.equal(backupCheckDelay(midnight),60000);
});
test('Cairo day boundaries respect Egyptian DST rather than a fixed UTC offset',()=>{
 assert.equal(backupDay(Date.parse('2026-10-29T21:30:00Z')),'2026-10-29');
 assert.equal(backupDay(Date.parse('2026-10-29T22:00:00Z')),'2026-10-30');
 assert.equal(backupDay(Date.parse('2026-04-23T21:59:59Z')),'2026-04-23');
 assert.equal(backupDay(Date.parse('2026-04-23T22:00:00Z')),'2026-04-24');
});
