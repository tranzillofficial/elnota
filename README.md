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
- Browser verification is pending: the browser download was unavailable in the execution environment.

Free infrastructure has finite capacity and may pause when inactive. Monitor usage and upgrade this independent backend as revenue grows. Direct thermal printing, governmental e-invoicing, automated reminders and team sharing are outside this release.
