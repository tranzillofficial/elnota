# ElNota | Security Requirements

## Threat model
Protect tenant financial data against cross-account leakage, stolen devices, compromised session tokens, forged sync requests, accidental administrator access and unreliable offline storage.

## Authentication and authorization
- Use Supabase Auth; store tokens using platform-appropriate secure storage when supported and tested.
- Apply **Row Level Security (RLS)** to every tenant-owned table. All read/write paths must enforce tenant membership and roles.
- Do not rely on hidden Flutter UI elements or client-side `workspace_id` checks for authorization.
- Privileged onboarding/activation, administrative overrides and webhook processing run server-side with authorization checks.
- On user switch/logout, clear cached session and segregate or erase decrypted user data on disk according to retention policy.

## Secrets and network
- Supabase **publishable/anon** client key is not a secret; secret/service-role keys must never appear in mobile/desktop binaries.
- Never include private API keys, passwords or tokens in repo, docs, screenshots, logs, backups or telemetry.
- Use TLS; validate server-side webhook signatures/verification per provider docs.
- Do not trust payment success redirects as proof of payment; verify independently before activation.

## Offline data
- SQLite is **not encrypted by default**. Assess threat model and choose tested encrypted-at-rest storage/key management before storing sensitive customer financial data on lost/stolen devices.
- Prevent cross-user cached-data leakage on shared computers.
- Backups must be encrypted and restorable; protect and rotate encryption keys; never silently upload customer data to consumer cloud storage.
- Biometrics/PIN are optional local unlock safeguards, **not** substitutes for Supabase authorization.

## Financial integrity
- Validate amounts, permissions and state transitions on the server, not only Flutter.
- Use idempotent, append-only financial events, audit trails, and server-controlled authorization.
- Record actor, timestamp, entity and approved reason for reversals/discounts.

## Privacy & governance
- Collect only necessary personal details; publish an understandable privacy policy and data deletion/contact process.
- Provide minimal role-based access to staff/admins; audit high-risk actions.
- Define retention, backup recovery and incident response before public rollout.
- Consider app-store requirements for privacy disclosure and account deletion where applicable.

## Review checklist
- [ ] RLS membership tests pass for own workspace, other workspace, unauthenticated access.
- [ ] Secrets scan clean; `.env` values appropriately separated, no server secrets in client.
- [ ] Device at-rest protection and logout behavior verified on Android/iOS/Windows.
- [ ] Payment activation verifies trusted webhook/source and is replay safe.
- [ ] Sensitive logs redact PII, financial details and auth tokens.
- [ ] User data export/deletion and backup restoration tested.


## Account activation gate (24 October 2026)
All native and Web accounting routes now require a persisted authenticated Supabase session plus approved `elnota_accounts` entitlement. No anonymous local owner or continue-offline login action is created. Signed-in pending users submit a `basic` activation request; only the existing admin-only `elnota_review` RPC approves it after the administrator verifies payment. Signup and `elnota_register` do not activate users.

Offline use follows a previous authenticated login and a server-verified active entitlement cached in FlutterSecureStorage, scoped to that user. The former editable GetStorage entitlement is not imported as trusted approval. Online suspension/deletion denies access; cloud expiry does not revoke a paid basic local licence. Offline revocation can only be learned on reconnection. Account DBs remain separate, and old local files are retained without migration/deletion. Public backend configuration is bundled consistently; it contains no service-role secret.

Production scope: local accounting/auth/activation fixes. Cloud ledger sync and v2 cloud backup remain disabled. An isolated free Supabase project could not be provisioned because the account already has two active free projects. The user chose to continue account/local fixes; this is not approval to launch untested cloud synchronization or touch legacy client data.


Release 1.0.4 verification: analyzer clean; 89 automated tests passed (one demo-only test skipped). A real confirmed test account signed in via the shared backend and Web UI, reached activation instead of the ledger, and signed out. Direct unsigned invoice navigation redirected to login. No activation request or payment approval was fabricated for this UI test. Signed ARM32/ARM64 APKs and the Windows x64 installer were built, published and their download lengths verified. Native installation/offline restart on the physical Huawei is still unverified (no connected device). Earlier new-repository preview releases were retained as recoverable drafts so their anonymous-local installers are no longer advertised or downloadable through public release links. Previously installed offline binaries cannot be remotely changed by this release.


## Admin landing fix (25 October 2026)
Password login, QR login and restored sessions resolve the landing route using the existing server-only `elnota_is_admin` check. Verified admins open `/admin` rather than a merchant activation form. Existing inactive-account sessions opened at `/home` also resolve the role before displaying payment fields. A failed role lookup never grants admin access, and merchant activation requirements remain unchanged. No account is automatically activated and no server roles, schema or customer rows are changed. Targeted auth/admin tests cover admin routing, failed verification, merchant gating and revocation.


## Activation request submission grant (25 October 2026)
The deployed requests table had authenticated SELECT only, while clients submit pending requests directly. A real authenticated request reproduced HTTP 403 / PostgreSQL 42501. Migration `20261025010000_activation_request_insert_columns.sql` restores INSERT on the seven client submission columns only. It does not grant UPDATE, DELETE, reviewer/timestamp fields or anonymous access. Existing RLS requires self ownership and pending/unreviewed status; the existing security-definer trigger verifies confirmed identity, blocks suspended/deleted accounts and stamps sender details from server records. Approval remains in the admin-only RPC.

Live verification used the existing clearly named technical test account: one pending request was saved and read back, self-approval/cross-user submission/review-field injection were denied, and the account remained inactive. The reference explicitly states TECHNICAL TEST ONLY / NOT A PAYMENT / DO NOT APPROVE. No customer ledger data was changed. Existing clients receive the permission fix without a new binary. A read-only regression check is in `supabase/tests/activation_request_permissions.sql`.
