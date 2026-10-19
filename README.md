# ElNota / النوتة

Arabic mobile-first Next.js application for customers, products, invoices, payments and optional cloud synchronization.

## Run

```sh
npm ci
cp .env.example .env.local
npm run dev
npm test
npm run build
```

Configure the three public environment variables in `.env.example` using a **dedicated** Supabase project. Never use an existing application database. Never expose service-role credentials in browser environment variables.

## Features

- Arabic responsive landing, email signup/login and password recovery.
- Installable PWA with local IndexedDB data and prepared offline access.
- Customers, products, invoice line snapshots, cash/credit/installments and payment history.
- WhatsApp sharing, print/PDF, archived products and retained voided invoices.
- Basic activation: EGP 1,000 once. Optional Cloud: EGP 50/month or 500/year. Manual payment review; no automatic billing.
- Owner-isolated cloud data, server-checked subscriptions and optimistic revision checks.
- Up to 10 MiB active cloud ledger excluding images, plus three previous snapshots.
- Automatic cloud save only while the app is open, online and enabled.
- Export/import JSON backups; personal Drive/Files/iCloud storage via download or system share. No direct personal-cloud OAuth integration.

## Backend setup

Apply the migration to a fresh dedicated database. Provision the administrator allowlist privately in the database; administrator identity is never configured in public source. Register and verify the administrator before opening `/admin`. Users cannot activate themselves or edit entitlement expiry.

Set Supabase Auth Site URL and permitted redirect URLs to the deployed origin (`/dashboard` and `/login`). Configure custom SMTP before public signup; the default sender is restricted. No Auth configuration endpoint was available in the connected tool.

## Data lifecycle

Local storage is per account, device and origin. Export regularly; clearing browser data or losing the device can lose unbacked-up records. Export from the temporary deployment origin before moving to a custom domain and import there. Cloud expiry stops writes but preserves existing read/export access. On sync conflict, export local data, retrieve the newer cloud snapshot and reconcile. Restore replaces the local ledger after confirmation and turns automatic sync off.

## Checks

- Production build, TypeScript and invoice/backup unit tests.
- Database transaction tests passed for activation restrictions, entitlement checks, revision conflicts, backup retention and cross-account isolation. Test fixtures were rolled back.
- Published-browser checks passed: landing rendering; demo customer creation; invoice at 85 with initial payment 25; later payment 20 leaving 40; persistence after reload. No application error was observed. Mobile viewport and offline reload could not be directly exercised because the local browser download was unavailable.
- A publication preview is included in `docs/preview.jpg`.

Free infrastructure has finite capacity and may pause when inactive. Monitor usage and upgrade this independent backend as revenue grows. Direct thermal printing, governmental e-invoicing, automated reminders and team sharing are outside this release.

## Invoice payment behavior

Credit invoices have no due date. New installment invoices finance the remaining balance after the initial payment over 1–120 whole months; the first payment is due one calendar month later. Month-end dates clamp to the last valid day, while subsequent dates remain anchored to the original invoice day. The last installment absorbs rounding cents. Overdue totals count only unpaid installments already past due. Product quantities use whole units with a step of one.

WhatsApp actions prepare a local PNG image with amounts, payments and installment schedule. A second explicit click shares the prepared image through the system share sheet where file sharing is supported; the user chooses WhatsApp and the recipient. Other browsers provide a PNG download for manual attachment. No text-only wa.me payload or public customer-data/image URL is used.

## Barcode / QR camera scanning

On the Products screen and in New Invoice, tap the scan icon beside product search to scan a barcode or a QR code containing a product identifier. Registered products can be found with their saved prices; a matched scan in a new invoice adds the product directly. Unknown codes open the new-product form with the identifier filled in, so the business owner can enter a name and price before saving. A separate scan action is available inside the product form.

Camera access requires a secure origin (HTTPS or localhost) and browser permission. The scanner uses a bundled client-side decoder (html5-qrcode with ZXing fallback) to support common Android and iOS browsers without uploading video frames to a server. A manual code input remains available if the camera is denied or unavailable. A scanned identifier is **not** an external product-database lookup: products not already stored in the ledger must be registered by the user.

Test on physical devices (iOS Safari and Android Chrome) with the specific EAN/UPC, Code 128, and QR labels used by the business before relying on it at checkout.
# Account-specific catalog imports

## Offline-first operation and synchronization

The dashboard hydrates the last locally authenticated account directly from IndexedDB before attempting any network calls. First online activation saves an empty local ledger too. Signing in explicitly switches the local account pointer; signing out removes it. Cached local data does not grant access to cloud APIs: synchronization checks the current server session and existing Cloud entitlement.

Settings provides two-way “مزامنة الآن”, optional automatic synchronization while the app is open, the last successful sync time, and a pending-local-changes indicator. A canonical SHA-256 business-data fingerprint and server revision distinguish local-only edits, remote-only edits, and divergent edits; images and local timestamps do not count as cloud changes. Divergent copies require an explicit choice with record counts, not an automatic overwrite. Compare-and-swap still guards server uploads, and the chosen cloud revision is rechecked before resolving a conflict. Three local recovery snapshots are retained before replacing or uploading data; server backups retain previous uploads. Matching local product photos survive downloads.

The build generates both `public/offline-assets.json` and `public/sw.js` from `scripts/service-worker.js`. Each build gets a distinct cache. HTML is served immediately from its matching cache; updates install only after their assets and app shell are ready. Account APIs and authentication requests are never cached. Open and prepare the installed app once online on each device before using it offline. No background sync is promised while the app is closed, and installation does not transfer another device's local data.

Catalog imports can carry a `categoryMap` to merge or rename categories on existing devices without changing product IDs, prices, quantities, archive status or invoices. Mappings also repair import markers written by older clients.

Settings includes installation and offline preparation controls. Chromium uses the browser installation prompt; iOS shows Add to Home Screen instructions. The build generates `public/offline-assets.json` so the service worker caches all static app assets, including lazy scanner chunks, before reporting readiness. After an online login on the same device, the last local account can reopen offline without trying to refresh its network session. Signing out clears that offline identity. IndexedDB remains the source of local customer, product and invoice data; installation on a different device or an isolated iOS app container requires restoring an exported backup.

The `account_catalog_imports` database migration adds `public.elnota_catalog_imports` (`id text primary key`, `user_id uuid` referencing `elnota_accounts`, `payload jsonb`, `created_at timestamptz`). Enable RLS and grant only SELECT to authenticated users; the owner policy requires `user_id = (select auth.uid())` and an activated account. Anonymous users and other accounts cannot read the data, and customers cannot write the source imports. Provision this migration when setting up a new database; catalog source data is deliberately kept out of this public repository.

On opening the dashboard online, the application fetches only the signed-in account's imports and merges new imports into its local IndexedDB ledger under the existing save lock. Import IDs are included in backups to avoid duplicates and preserve edits and archived products. Four-field catalogs display name, box quantity, item number and price, grouped by worksheet/category, without images. Box quantity is separate from invoice quantity; zero input means one piece. Missing source quantities remain unspecified and missing prices must be entered before adding an item to an invoice. Accounts without catalog imports keep their existing product interface.

## Customer deletion and amount-only invoices

Customer details offer explicit deletion with an invoice count and outstanding-balance warning. The action saves a local recovery snapshot before removing the customer and their associated invoices, keeping all other accounts intact. Recovery is available from Settings. Amount-only invoice entry creates one manual accounting line without adding a catalog product, preserving compatibility with payments, installment schedules, local backups and cloud sync. Printed receipts, invoice images and text summaries display the amount description without product columns. Amounts must be positive with at most two decimal places.

## Cairo-midnight backups and compact settings (October 19, 2026)

Settings now groups business details, export/import, daily-backup health, optional two-way sync and installation in a compact responsive workspace. Last upload time and pending offline copies are visible. Backup creation is independent of the optional sync toggle and never resolves a sync conflict or replaces the active cloud/local ledger.

A running dashboard takes one snapshot per Africa/Cairo calendar day, checked at minute boundaries including midnight. If the browser is suspended or closed, capture happens on its next opening. Offline captures are stored transactionally in IndexedDB (latest seven pending snapshots); online/focus/resume events retry uploads. Stable per-snapshot UUIDs make a lost-response retry idempotent. An explicitly checked account identity prevents uploading one cached account's data into another active session. Fresh empty devices without a sync baseline do not upload empty snapshots over useful backups. Product images remain excluded and the 10 MiB cap is enforced locally and in PostgreSQL.

`20261019162212_midnight_backups.sql` adds an RLS-protected device-backup table, a metadata-only security-invoker view, and a guarded upload RPC. Three latest uploaded JSON snapshots per account are retained, separate from sync history and the existing daily server snapshot. Admin account summaries show the latest device file, original capture time, actual server upload time and size, with JSON download. Cloud-sync saves and server-generated snapshots are labeled separately; no device upload is inferred from a server snapshot.

The same migration registers `elnota-midnight-cairo` using pg_cron. Its hourly UTC trigger runs a server-only function that writes only when Cairo's local hour is 00, handling seasonal UTC offsets. It copies the latest already-synchronized cloud data for active, activated subscribers; it cannot access unsent offline changes. Accounts with no cloud row have no cloud data to snapshot. Clients cannot invoke the server job. The database must be running for scheduled execution. Deployment registers the job; the first future midnight run must be checked through `cron.job_run_details` after it occurs.

Validation: 37 application unit tests, durable IndexedDB queue/concurrent-tab tests, transport retry/account-switch runner tests, PostgreSQL RLS/subscription/idempotency/retention/admin-view/cron-branch tests, TypeScript and production build. PostgreSQL tests use isolated fixtures, not production customer records. Browser/physical-device visual testing was unavailable in this session.

Additional backup tests: install `@electric-sql/pglite` and `fake-indexeddb` in a temporary test prefix, set `BACKUP_TEST_DEPS` to its absolute node_modules path, then run `node tests/backup-queue.cjs`, `node tests/backup-database.cjs` and `node tests/backup-runner.cjs` (runner has no external test dependency).

## Admin activation controls and request identity (October 19, 2026)

Each account has an “إدارة الحساب” menu with suspension/resumption and reversible deletion from the main list. Deleted accounts appear under “المحذوفون”; restoring an account to the list keeps it suspended until a separate resumption action. No Auth user, invoice, cloud backup or payment history is physically deleted. Pending activation requests are rejected when an account is deleted from the list. A delete confirmation requires retyping the actual account email. Verified admin accounts, including the current administrator, are protected server-side.

`20261019163602_admin_account_controls.sql` saves the original activation, cloud expiry and printing flag during suspension. It clears active entitlements immediately on the server, with a database guard preventing older approval/cloud/printing RPCs from inadvertently bypassing suspension. Resuming restores the original paid state and expiry, never extends Cloud, and never activates an account that was unpaid originally. Actions are recorded in a private audit table. The offline app receives administrative revocation on its next successful account refresh; an offline device cannot receive a remote revocation or remote data erasure. Local writes are blocked after that refresh, while exporting existing local data remains available in Settings.

Request submission stamps the sender email from `auth.users` and account name server-side, tied to the existing authenticated `user_id`. Historical requests are backfilled through their actual user association, never from free-text payment notes. The admin request card labels sender identity, account UUID, phone and payment notes separately and warns about a phone appearing on different accounts. Approval confirmation names the exact account. The customer form also shows which signed-in account will submit the request. Client input cannot insert or overwrite sender-stamp columns.

Validation: `tests/admin-accounts.cjs` uses isolated PostgreSQL to cover sender stamping/backfill, forged-user/field rejection, admin protection, entitlement preservation, suspended cloud/printing/request denial, reversible deletion, inactive unpaid restoration and private audit isolation. Application tests and production build pass. No existing production account was suspended, deleted or reactivated as part of this release. Browser/physical-device visual testing remains unverified in this session.
