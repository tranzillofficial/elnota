export type SyncRunnerOptions={sync:()=>Promise<void>;onError:(error:Error)=>void;onSettled:()=>void;active:()=>boolean;setTimer:(callback:()=>void,delay:number)=>ReturnType<typeof setTimeout>;clearTimer:(timer:ReturnType<typeof setTimeout>)=>void};
/** One in-flight sync, durable local data as the queue, retries and a short polling interval. */
export function startCloudSync(options:SyncRunnerOptions){let stopped=false,running=false,dirty=false,failures=0;let timer:ReturnType<typeof setTimeout>|undefined;
 const schedule=(delay:number)=>{if(stopped)return;if(timer!==undefined)options.clearTimer(timer);timer=options.setTimer(()=>{timer=undefined;void run()},delay)};
 async function run(){if(stopped)return;if(running){dirty=true;return}if(!options.active()){schedule(15000);return}running=true;dirty=false;
 try{await options.sync();failures=0}catch(error){failures++;if(!stopped)options.onError(error instanceof Error?error:new Error(String(error)))}finally{running=false;if(!stopped){options.onSettled();schedule(dirty?600:failures?Math.min(30000,1500*2**Math.min(failures-1,5)):15000)}}}
 schedule(0);
 return {changed(){dirty=true;if(!running)schedule(600)},wake(){if(!running)schedule(0);else dirty=true},stop(){stopped=true;if(timer!==undefined)options.clearTimer(timer)}};
}
