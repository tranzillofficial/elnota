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
