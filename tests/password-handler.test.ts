import test from 'node:test';
import assert from 'node:assert/strict';
import {passwordHandler} from '../supabase/functions/elnota-password/handler.mjs';
const adminId='10000000-0000-4000-8000-000000000001',target='10000000-0000-4000-8000-000000000002';
function setup({authenticated=true,isAdmin=true,disabled=false,exists=true}={}){
 const writes:{id:string;password:string}[]=[];let checks=0;
 const session={auth:{getUser:async()=>({data:{user:authenticated?{id:adminId}:null},error:null})},rpc:async()=>({data:isAdmin,error:null}),from:()=>({select:()=>({eq:()=>({maybeSingle:async()=>({data:exists?{user_id:target,suspended_at:disabled?'now':null,deleted_at:null}:null,error:null})})})})};
 const handler=passwordHandler((_url:string,key:string)=>{checks++;return key==='SUPABASE_SERVICE_ROLE_KEY'?{auth:{admin:{updateUserById:async(id:string,{password}:{password:string})=>{writes.push({id,password});return {error:null}}}}}:session},(key:string)=>key);
 const request=(body:unknown={user_id:target,password:'new-secure-pass'},auth=true)=>handler(new Request('https://example.test/password',{method:'POST',headers:auth?{authorization:'Bearer validated-session'}:{},body:JSON.stringify(body)}));
 return {request,writes,checks:()=>checks};
}
test('missing, invalid and non-admin sessions cannot reset any password',async()=>{
 const missing=setup();assert.equal((await missing.request(undefined,false)).status,401);assert.equal(missing.checks(),0);
 for(const options of [{authenticated:false},{isAdmin:false}]){const s=setup(options);assert.ok([401,403].includes((await s.request()).status));assert.equal(s.writes.length,0);assert.equal(s.checks(),1);}
});
test('verified admin resets the selected account directly without email operations',async()=>{
 const s=setup();assert.equal((await s.request()).status,200);assert.deepEqual(s.writes,[{id:target,password:'new-secure-pass'}]);assert.equal(s.checks(),2);
});
test('invalid passwords, absent and suspended accounts are rejected',async()=>{
 for(const password of ['short','x'.repeat(129)]){const s=setup();assert.equal((await s.request({user_id:target,password})).status,400);assert.equal(s.writes.length,0);}
 for(const options of [{disabled:true},{exists:false}]){const s=setup(options);assert.ok([404,409].includes((await s.request()).status));assert.equal(s.writes.length,0);}
 const own=setup();assert.equal((await own.request({user_id:adminId,password:'new-secure-pass'})).status,400);assert.equal(own.writes.length,0);
});
