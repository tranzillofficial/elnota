const headers={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS','Content-Type':'application/json','Cache-Control':'no-store'};
const reply=(status,message)=>new Response(JSON.stringify({message}),{status,headers});
export function passwordHandler(createClient,env){return async req=>{
 if(req.method==='OPTIONS')return new Response(null,{status:204,headers});
 if(req.method!=='POST')return reply(405,'METHOD_NOT_ALLOWED');
 const authorization=req.headers.get('authorization')??'';
 if(!authorization.startsWith('Bearer '))return reply(401,'AUTH_REQUIRED');
 try{
  const session=createClient(env('SUPABASE_URL'),env('SUPABASE_ANON_KEY'),{global:{headers:{Authorization:authorization}},auth:{persistSession:false,autoRefreshToken:false}});
  const {data:identity,error:identityError}=await session.auth.getUser(authorization.slice(7));
  if(identityError||!identity.user)return reply(401,'AUTH_REQUIRED');
  const {data:isAdmin,error:adminError}=await session.rpc('elnota_is_admin');
  if(adminError||isAdmin!==true)return reply(403,'ADMIN_REQUIRED');
  const raw=await req.text();if(raw.length>4096)return reply(413,'REQUEST_TOO_LARGE');
  let body;try{body=JSON.parse(raw)}catch{return reply(400,'INVALID_REQUEST')}
  const {user_id,password}=body??{};
  if(typeof user_id!=='string'||!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(user_id)||typeof password!=='string'||password.length<8||password.length>128)return reply(400,'INVALID_PASSWORD');
  if(user_id===identity.user.id)return reply(400,'USE_ACCOUNT_SETTINGS');
  const {data:account,error:accountError}=await session.from('elnota_accounts').select('user_id,suspended_at,deleted_at').eq('user_id',user_id).maybeSingle();
  if(accountError||!account)return reply(404,'ACCOUNT_NOT_FOUND');
  if(account.suspended_at||account.deleted_at)return reply(409,'ACCOUNT_DISABLED');
  const admin=createClient(env('SUPABASE_URL'),env('SUPABASE_SERVICE_ROLE_KEY'),{auth:{persistSession:false,autoRefreshToken:false}});
  const {error}=await admin.auth.admin.updateUserById(account.user_id,{password});
  if(error)return reply(400,'PASSWORD_UPDATE_FAILED');
  return reply(200,'PASSWORD_UPDATED');
 }catch{return reply(500,'PASSWORD_UPDATE_FAILED')}
}}
