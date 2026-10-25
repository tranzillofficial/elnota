# Production safety and delivery boundaries

All implementation changes belong to `tranzillofficial/elnotaapp`.
`tranzillofficial/elnota` is READ ONLY and shares a Supabase project containing
active customer data. No SQL migration, schema edit, production restore, cloud
ledger write, deployment, or admin action was executed as part of this work.

The legacy production database stores ledger JSON documents. The new local
Flutter model is relational. These are NOT interchangeable. For that reason:
- `ENABLE_RELATIONAL_SYNC` defaults to false, including direct push/pull calls.
- `ENABLE_ADMIN_WRITES` defaults to false. The new admin dashboard is read-only.
- `ENABLE_V2_CLOUD_BACKUP` defaults to false. The new backup table/RPC and
  catalog override migration are staged files only, never applied to production.
- No startup job applies SQL files from this repository.
- Do not run `db_structure/supabase_migration_relational.sql` on the shared live
  project. It remains a reference proposal, not a release instruction.
- QR migration/function files are additive preparation only. Stage-test them
  in an isolated project before any separate approved production deployment.

The admin UI calls the existing server `elnota_is_admin` function and existing
RLS-protected account/request endpoints. It never uses editable user metadata
or a client-side email allowlist to grant access. No service-role key is shipped
in Flutter. Delete/restore/purge controls are deliberately absent.

Admin activation review/printing handlers exist behind `ENABLE_ADMIN_WRITES`;
when separately enabled they still call the existing protected RPCs and require
an explicit in-app confirmation. They are never run automatically by loading
or testing the dashboard.

Native local ledgers are separated by authenticated user ID. Signing in to a
server account opens its own local file rather than overwriting or importing
an existing local business. QR pairing establishes an authenticated session;
it does not import the legacy ledger document or promise cloud convergence.
