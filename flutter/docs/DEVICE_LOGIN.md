# Device login (QR)

Prepared in the NEW repository only. Cloud deployment and end-to-end phone /
server verification have NOT been performed. No existing application tables,
RLS policies, cloud documents, customer rows or backups were modified.

## Protocol
1. The web client requests a challenge from `device-login`.
2. The server creates a random UUID, 256-bit browser secret, six-digit comparison
   code, and three-minute expiration. Only the secret hash is stored server-side.
3. The QR contains only `elnota://link-device?challenge=<UUID>`. It contains no
   browser secret, access token, refresh token, email or password.
4. The phone's camera opens the Android app through the native intent bridge.
   Settings also offers manual pairing-code entry; no camera package was added.
5. A signed-in phone inspects the challenge. The user compares the six-digit
   code and explicitly approves. The Edge Function verifies the Supabase user,
   confirmed email and existing non-suspended/non-deleted activated account.
6. Only the browser holding the private secret can poll successfully. A single
   atomic SQL update consumes an approved challenge before minting a short-lived
   Supabase magic-link hash. Concurrent/replayed polls cannot consume it twice.
7. Flutter verifies that one-time hash with `verifyOTP(type: OtpType.email)`;
   Supabase manages the resulting browser session. No phone token is copied.

CORS is pinned to `https://app.elnota.shop` by default. Mobile/native requests
without Origin still require valid authentication for inspect/approve. Creation
is limited to five challenges per minute per hashed requester IP, using a
transaction-scoped advisory lock. Responses are no-store and errors never echo
credentials. The pairing table has RLS and no anon/authenticated table grants;
only the Edge Function's server-side service-role identity accesses it.

## Staging checklist (separate from this local implementation)
- Use an isolated Supabase project with a test `elnota_accounts` contract.
- Review/apply `supabase/migrations/202610230001_device_login.sql` there only.
- Deploy `supabase/functions/device-login` with `verify_jwt = false`; the handler
  manually authenticates protected actions. Keep service keys in server secrets.
- Set `ALLOWED_APP_ORIGIN` and `DEVICE_LINK_RATE_SALT` as deployment secrets.
- Build Flutter with SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY (public client key).
- Verify wrong secrets, non-admin/non-active accounts, expiration, races, replay,
  denied Origin, rate limits, cancellation, two simultaneous phones, and mobile
  background/resume on a real device. No success claim until those pass.
- Schedule cleanup for expired rows after an agreed audit retention period;
  creation rate checks do not delete any rows automatically.

Android URI routing is implemented without adding a dependency. iOS/native QR
routing and an in-app camera scanner are not included in this change. Windows
32-bit users can use a supported browser; no 32-bit Flutter installer exists.
