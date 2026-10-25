# ElNota | Database Contract

> Proposed schema blueprint. **Do not automatically apply** without inspecting the project's existing Supabase/Drift schema, migrating existing data safely, and approval for production changes.

## Storage principles
- Offline records use UUIDv4/UUIDv7 client-generated IDs, never sequential IDs as cross-device identity.
- Each business-owned row carries `tenant_id` (or `workspace_id`), `created_at`, `updated_at`, `version`, optional `deleted_at`.
- Server assigns authoritative versions / timestamps; clients use local timestamps for UI only, not conflict ordering.
- Store money in a consistent currency and exact integer minor units (`*_minor BIGINT/INTEGER`); keep ISO `currency_code` if multi-currency might be supported. Define rounding explicitly before implementation.
- Postgres foreign keys/indexes + matching SQLite indexes for lookups; DB constraints enforce nonnegative quantities and validated enums.

## Proposed entities (adjust to actual ElNota features)
| Table | Primary relationships | Purpose |
|---|---|---|
| `workspaces` | owner/member association | business/account data boundary |
| `workspace_members` | user_id -> workspace_id | permissions, RLS membership |
| `customers` | workspace_id | customer profile and optional phone |
| `products` | workspace_id | optional product catalog |
| `invoices` | workspace_id, customer_id | sale/credit/installment invoice header |
| `invoice_items` | invoice_id, product_id nullable | item snapshots, amounts; allow manual amount-only invoice |
| `payments` | workspace_id, customer_id | independent customer-level receipts; **not per-invoice by default** |
| `payment_allocations` | payment_id, invoice_id | optional future explicit allocations; not required for account-level payment |
| `installment_plans` | customer_id, invoice_id optional | terms, schedule rules |
| `installment_schedule` | plan_id | due amounts and dates |
| `ledger_entries` | workspace_id, customer_id, source_id | immutable debit/credit events |
| `sync_outbox` | local only | durable queued operations |
| `sync_state` | local only | last acknowledged server cursor per workspace |
| `audit_events` | workspace_id | actor, action, before/after metadata, traceability |

## Critical identities & consistency
- `invoices`: unique `(workspace_id, invoice_number)` only if invoice numbering policy is defined.
- `payments`: unique `(workspace_id, id)`; an idempotency key makes retries safe.
- `ledger_entries`: unique `(workspace_id, source_type, source_id, event_type)` where applicable.
- Choose a stable sorting key for transaction history (`server_sequence`, event UUID fallback).
- Never overwrite or physically delete posted ledger events. Correct with reversal/adjustment entries and audit trail.
- Use a `deleted_at` tombstone for syncable deletions; disallow deleting customers with financial history unless an approved archival policy is implemented.

## Core queries
- Customer overview: invoices/debits minus receipts/credits derived from ledger (do not sum mutable UI totals).
- List customers with search and paging; add indexes for `workspace_id`, normalized name/phone.
- Stream customer invoice history and customer-level payment history separately.
- Financial totals should be reproducible from ledger events; cached aggregates are projections, not source of truth.

## Local Drift example (illustrative only)
```dart
class SyncOutbox extends Table {
  TextColumn get operationId => text()();
  TextColumn get workspaceId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get payloadJson => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {operationId};
}
```

## Migrations
1. Review deployed schema, policies, migration history and actual populated records.
2. Write additive Postgres migration and a corresponding Drift `schemaVersion` upgrade.
3. Backfill safely and verify counts, balances, constraints and workspace isolation.
4. Stage-test upgrade **from every supported app version** and from an old offline DB.
5. Use expand/migrate/contract; don't drop old columns until all supported clients have upgraded.
6. Take verified backups and document recovery before production deployment.

## Security
- Enable RLS on every workspace-scoped server table; queries and writes require authenticated membership and suitable role.
- Client-provided workspace IDs are not authority. The server checks membership on every mutation.
- Never ship service-role keys or secrets in Flutter; keep privileged actions in protected server functions.

## Open decisions before migration
- Is there one workspace per user or multi-user/team access?
- Can an invoice be edited after posting, or must changes be a correction event?
- What is the exact outstanding balance sign convention and handling of customer advances?
- Currency precision, invoicing/discount/tax policies and retention period?

## Local additive migration: version 2
`AppConstants.dbVersion` is 2. The Drift upgrade creates the existing raw SQL
schema idempotently and adds `invoice_terms` without dropping/replacing records.
A real in-memory v1 fixture verifies existing customers survive the upgrade.

`invoice_terms`: invoice_id (PK), workspace_id, customer_id, method
(cash/credit/installments), upfront_minor, months (1..120), first_due_date.
Amounts remain integer minor units. Existing invoices need no backfill; absence
of terms preserves their legacy credit display. New invoice + terms + upfront
receipt + ledger + outbox are atomic. Backups include customers, invoices,
invoice_items, payments, ledger_entries, invoice_terms and pending outbox.

Raw SQL streams use a local commit/invalidation signal because these tables
are not generated Drift entities. Tests verify balance streams refresh after
payment and duplicate receipts remain idempotent.

This is a LOCAL migration only. No production Supabase migration was run. Do not
apply relational proposal SQL to the legacy JSON production database.

## Local version 3: catalog
Additive `product_categories` and `catalog_products` tables, scoped by workspace
inside each account-specific database file. Active category names and barcodes
are unique per workspace; barcode values stay text, preserving leading zeroes.
Products reference a category and store exact integer prices, optional WebP
base64 (at most 512 KiB decoded) and description. Archiving retains rows and
outbox tombstones; a populated category cannot be archived. Each mutation and
its outbox entry are atomic. Backups include both tables. No existing ledger
table or value is changed. Catalog streams read the persistent local cache.

The staged SQL for feature overrides and v2 device backups is NOT applied.
Its new tables never overwrite legacy `elnota_cloud` or production backups.
