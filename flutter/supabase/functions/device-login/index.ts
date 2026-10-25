import { createClient } from 'npm:@supabase/supabase-js@2.117.3';
import { sha256, randomSecret, uuidPattern, isExpired } from './protocol.ts';

const appOrigin = Deno.env.get('ALLOWED_APP_ORIGIN') ?? 'https://elnotaapp-web-preview.vercel.app';
const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { persistSession: false, autoRefreshToken: false } });
Deno.serve(async (req: Request) => {
  const origin = req.headers.get('origin');
  const headers = { 'Content-Type': 'application/json', 'Cache-Control': 'no-store', 'Access-Control-Allow-Origin': appOrigin, 'Vary': 'Origin', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
  const reply = (body: object, status = 200) => new Response(JSON.stringify(body), { status, headers });
  if (origin && origin !== appOrigin) return reply({ error: 'Origin not allowed' }, 403);
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers });
  if (req.method !== 'POST') return reply({ error: 'Method not allowed' }, 405);
  try {
    const text = await req.text();
    if (text.length > 2048) return reply({ error: 'Request too large' }, 413);
    const body = JSON.parse(text);
    if (body.action === 'create') {
      const id = crypto.randomUUID();
      const secret = randomSecret();
      const code = String(crypto.getRandomValues(new Uint32Array(1))[0] % 1000000).padStart(6, '0');
      const ip = req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ?? 'unknown';
      const { error } = await admin.rpc('elnota_create_device_link', { p_id: id, p_browser_hash: await sha256(secret), p_requester_hash: await sha256(ip + (Deno.env.get('DEVICE_LINK_RATE_SALT') ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'))), p_code: code, p_label: (req.headers.get('user-agent') ?? 'Browser').slice(0, 120) });
      if (error) return reply({ error: 'Unable to create link; retry later' }, 429);
      return reply({ id, secret, code, expires_at: new Date(Date.now() + 180000).toISOString(), link: `elnota://link-device?challenge=${id}` });
    }
    if (typeof body.id !== 'string' || !uuidPattern.test(body.id)) return reply({ error: 'Invalid challenge' }, 400);
    if (body.action === 'poll') {
      if (typeof body.secret !== 'string' || !/^[0-9a-f]{64}$/.test(body.secret)) return reply({ error: 'Invalid proof' }, 400);
      const browserHash = await sha256(body.secret);
      const { data: row, error } = await admin.from('elnota_device_links').select('expires_at,approved_user,consumed_at').eq('id', body.id).eq('browser_hash', browserHash).maybeSingle();
      if (error || !row || isExpired(row.expires_at) || row.consumed_at) return reply({ status: 'expired' }, 410);
      if (!row.approved_user) return reply({ status: 'pending' });
      // Atomic compare-and-set consumes the proof once; concurrent polls cannot mint two sessions.
      const { data: claimed, error: claimError } = await admin.rpc('elnota_consume_device_link', { p_id: body.id, p_browser_hash: browserHash });
      if (claimError || !claimed?.length) return reply({ status: 'expired' }, 410);
      const userId = claimed[0].approved_user;
      const { data: account } = await admin.from('elnota_accounts').select('user_id').eq('user_id', userId).not('activated_at', 'is', null).is('suspended_at', null).is('deleted_at', null).maybeSingle();
      const { data: identity, error: userError } = await admin.auth.admin.getUserById(userId);
      if (userError || !account || !identity.user?.email || !identity.user.email_confirmed_at) return reply({ error: 'Account unavailable' }, 403);
      const { data: link, error: linkError } = await admin.auth.admin.generateLink({ type: 'magiclink', email: identity.user.email });
      if (linkError || !link.properties?.hashed_token) return reply({ error: 'Please regenerate the code' }, 503);
      return reply({ status: 'approved', token_hash: link.properties.hashed_token });
    }
    const jwt = req.headers.get('authorization')?.replace(/^Bearer\s+/i, '');
    if (!jwt) return reply({ error: 'Sign in on your phone first' }, 401);
    const { data: auth, error: authError } = await admin.auth.getUser(jwt);
    if (authError || !auth.user || !auth.user.email_confirmed_at) return reply({ error: 'Invalid session' }, 401);
    const { data: account } = await admin.from('elnota_accounts').select('user_id,email').eq('user_id', auth.user.id).not('activated_at', 'is', null).is('suspended_at', null).is('deleted_at', null).maybeSingle();
    if (!account) return reply({ error: 'Account is not active' }, 403);
    const { data: challenge } = await admin.from('elnota_device_links').select('verification_code,browser_label,expires_at,approved_user,consumed_at').eq('id', body.id).maybeSingle();
    if (!challenge || isExpired(challenge.expires_at) || challenge.approved_user || challenge.consumed_at) return reply({ error: 'Challenge expired' }, 410);
    if (body.action === 'inspect') return reply({ code: challenge.verification_code, browser: challenge.browser_label, email: auth.user.email, expires_at: challenge.expires_at });
    if (body.action === 'approve' && body.code === challenge.verification_code) {
      const { data, error } = await admin.from('elnota_device_links').update({ approved_user: auth.user.id, approved_at: new Date().toISOString() }).eq('id', body.id).is('approved_user', null).is('consumed_at', null).gt('expires_at', new Date().toISOString()).select('id');
      if (error || !data?.length) return reply({ error: 'Challenge unavailable' }, 409);
      return reply({ status: 'approved' });
    }
    return reply({ error: 'Invalid action' }, 400);
  } catch { return reply({ error: 'Device link unavailable' }, 400); }
});
