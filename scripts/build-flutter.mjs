import {existsSync, mkdirSync, cpSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
const sdk=process.env.FLUTTER_SDK || (process.platform==='win32'?'D:/Nedaa/flutter':join(tmpdir(),'elnota-flutter-3.47.7'));
function run(cmd,args,cwd=process.cwd()){
 const result=spawnSync(cmd,args,{cwd,env:process.env,stdio:'inherit',shell:process.platform==='win32'});
 if(result.status!==0)throw new Error(`Build command failed: ${cmd}`);
}
if(!existsSync(join(sdk,'bin',process.platform==='win32'?'flutter.bat':'flutter')))run('git',['clone','--depth','1','--branch','3.47.7','https://github.com/flutter/flutter.git',sdk]);
const flutter=join(sdk,'bin',process.platform==='win32'?'flutter.bat':'flutter');
const cwd=resolve('flutter');
run(flutter,['config','--no-analytics'],cwd);
run(flutter,['pub','get','--enforce-lockfile'],cwd);
// V2 cloud uses separately reviewed tables, server CAS and immutable financial history.
// Legacy documents and backups remain available for recovery.
run(flutter,['build','web','--release','--no-pub','--no-wasm-dry-run','--base-href=/app/','--build-name=1.0.5','--build-number=2006','--dart-define=ENABLE_ADMIN_WRITES=true','--dart-define=ENABLE_RELATIONAL_SYNC=true','--dart-define=ENABLE_V2_CLOUD_BACKUP=true'],cwd);
mkdirSync('public/app',{recursive:true});
cpSync('flutter/build/web','public/app',{recursive:true});
console.log('Flutter web prepared at /app/; Next.js owns landing and SEO.');
