# Production cutover preparation — 25 October 2026

Authorized target: tranzillofficial/elnota, Vercel project elnota, elnota.shop.
The Flutter project is vendored under flutter/ in the original repository.
Next.js remains at the root; generated Flutter Web files go to public/app/.
/admin redirects to /app/#/admin and /recover exports legacy browser data.
/dashboard and /legacy-admin retain the old interfaces during recovery.

## Preservation audit
The four named real accounts already exist and are activated. The real admin
is in the existing server allowlist; no role was granted by matching client email.
No legacy cloud document exists for any of the four named accounts. The single
available device backup for one of them contains zero customers, invoices or
products. Their device-only data cannot be recovered from email addresses.
Other users have two existing cloud documents and two daily copies; these were
preserved. A Windows-user-encrypted DPAPI snapshot of all cloud/backup/account/
request rows was exported outside Git and successfully decrypted for verification.
No passwords, auth tokens or auth.users password hashes were included.

## Import contract
Settings accepts original schemaVersion=1 JSON (raw or {data:...}) and current
schema_version=3 snapshots. It previews counts, balance and conversion notes;
checks owner when available; preserves original JSON in local import_archives;
refuses to merge into a nonempty database; and commits all rows in one transaction.
Repeated identical files do not create records twice. Old addresses become notes,
barcodes stay text, fractional item quantities retain their original description
and exact invoice subtotal, and product images convert to WebP before commit.
Voided invoices remain in history without contributing charges or receipts.
Customer payments plus active invoice receipts become independent ledger receipts.
Invalid dates, unsupported currencies and inconsistent financial records abort.
New snapshots include original archives, so future exports retain migration evidence.
Legacy settings and new business profile are restored account-locally.
Pending outbox and sync cursors are intentionally not replayed from another device.

## Live actions and validation
Only the clearly named technical test account was activated after explicit user
authorization. Password Auth and active entitlement were rechecked using the
native build's backend config. This is an API test, not a physical Android install.
The additive catalog permission table and admin-only RPC were applied; transactional
RLS tests for admin write, own read, denied merchant write and anon denial passed
and were rolled back. No financial/legacy cloud schema was changed.
Next.js 16.4.0 had critical audit findings; updated to 16.4.3, npm audit is clean.
Flutter pubspec.yaml and pubspec.lock remain unchanged.

## Versioned cloud verification and release limits
V2 cloud and daily backups use new tables; legacy cloud documents and backups remain intact.
A compare-and-swap RPC enforces ownership, active cloud entitlement, immutable posted
financial rows and validated totals. Three-way client merging preserves independent
receipts and rejects concurrent edits without silently overwriting either device.
Existing legacy cloud must reconcile invoice IDs, totals and balances before first migration.
The original sync body is retained privately; migrated users are prevented from creating
an independent legacy cloud branch. Nonmigrated legacy users continue unchanged.
106 Flutter tests passed, one demo-only test skipped. Live API checks passed for ownership,
legacy reconciliation, concurrent receipts/retry, immutability, subscription expiry,
suspension, history and daily backup idempotency. Browser import of the technical
fixture preserved the invoice and both receipts. These tests used only our technical account.
All named real account rows and legacy cloud/backup contents match the encrypted baseline.
A legacy daily backup timestamp advanced through the existing scheduled job without data changes.
Release flags enable V2 on every new platform build after these checks.
Physical Android installation and Windows installation remain unverified on user hardware.
Daily uploads catch up on reconnect/resume; execution at midnight with the app terminated
is not guaranteed. Device-only customer data requires an original backup file to import.
