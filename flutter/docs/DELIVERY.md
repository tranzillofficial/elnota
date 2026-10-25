# Implementation delivery

All changes are for `tranzillofficial/elnotaapp`. The old repository and shared
production Supabase project were not modified. See PRODUCTION_SAFETY.md before
connecting any build to production.

Implemented RTL dashboard, customers, account details, statements, invoices with
integrated installment schedules, invoice/payment modals, settings, and an admin
dashboard. Payments are projected against the oldest due obligation first using
integer minor units. Local schema upgrades are additive and tested for data
preservation. Cloud ledger synchronization and admin writes default to disabled.

The QR client, mobile approval bridge and server implementation are included.
The SQL and Edge Function have not been deployed or tested against production.
An isolated staging project is required for end-to-end pairing verification.

The Next.js downloads integration is supplied under integrations/nextjs without
editing the old landing repository. Release download links remain unset until
signed artifacts exist. Windows x86 is unsupported; the web app is the fallback.
The Windows x64 installer definition requires Inno Setup. The existing Android
release configuration uses debug signing, so its APK is for local testing only.

Earlier verification produced successful Windows x64 and JavaScript web builds,
an Android APK, responsive widget checks at phone/desktop widths, accounting and
admin protection tests, and a browser startup check. The earlier full test run
found one missing direct-sync guard; that guard was fixed and its targeted tests
passed. The final small changes (money parsing and account-scoped preferences)
could not be revalidated locally because the Flutter SDK on drive D: is no longer
available in this session. GitHub verification runs analysis, the full test suite,
web compilation and QR protocol tests. Build outputs are not committed.

No deployment, production migration, customer import or artifact publication is
part of this source delivery. Existing production customers remain on the old
application until the compatibility and staged migration work is approved.

## Standalone landing preview — 23 October 2026

The user subsequently authorized a separate Next.js landing preview. It is now
in `landing/` and deployed at https://elnotaapp-landing-preview.vercel.app on
the independent Vercel project `elnotaapp-landing-preview`. No old domain was
attached and no old Vercel project was changed. Preview pages are noindex.

`next build` and TypeScript checking passed. The Flutter SDK became available
again and all 60 Flutter tests passed. The one unnecessary test import reported
by analysis was removed. The deployed landing was checked in the browser,
including desktop/mobile layout, the Web entry page, and FAQ expansion.

The user chose landing preview only instead of creating a test Supabase project.
No new project or QR backend deployment was created. `/web` truthfully displays
the pending setup status. APK/installer downloads are still unavailable.
