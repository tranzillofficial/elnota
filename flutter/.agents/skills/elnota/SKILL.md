---
name: elnota-flutter-engineering
description: Offline-first Flutter/GetX/Drift/Supabase engineering workflows for the ElNota accounting app.
---

# ElNota Engineering Skill

Use this skill whenever adding or changing an ElNota feature, database schema, synchronization behavior, authentication, printing, or mobile/desktop behavior. Read `AGENTS.md` and `DESIGN.md` first.

## Workflow A — Add a feature
1. Identify domain entity, ownership (`tenant_id`), and financial invariants.
2. Add/extend Drift tables and DAO queries, plus safe migration and tests.
3. Add repository methods returning Drift streams and typed operation results.
4. Route mutations through local transaction + sync outbox.
5. Add GetX controller for reactive state and actions; bind via `Bindings`.
6. Build UI in `features/<feature>/views/` using design tokens; make phone and desktop responsive.
7. Cover offline create/edit/delete, stale session, conflict, retry, empty and error states.
8. Run formatting, analysis and targeted tests. State results precisely.

## Workflow B — Implement sync
**Recommended outbox columns:** `operation_id`, `tenant_id`, `entity_type`, `entity_id`, `operation_type`, `payload`, `base_version`, `created_at`, `attempts`, `next_retry_at`, `status`, `last_error`.

**Remote records:** UUID primary key, tenant key, version, server timestamps, and soft-delete marker where applicable.

Push loop:
1. Acquire single-run mutex; ensure authenticated session and reachability.
2. Read ordered pending outbox records.
3. Send stable idempotency key and expected version to trusted server endpoint.
4. On accepted result, atomically mark acknowledged/update local server version.
5. On conflict, store explicit conflict state for reconciliation; never discard user changes silently.
6. On transient errors, back off and retry; never submit an operation with a new ID.

Pull loop:
1. Fetch paginated tenant-scoped deltas after persisted cursor/checkpoint.
2. Merge in local transaction while protecting unsent local mutations.
3. Apply soft-deletes/tombstones and advance cursor only after commit.
4. Invalidate/refresh affected Drift streams through ordinary DB updates.

**Financial rule:** Persist independent payment events with unique IDs and server-side idempotency. Never merge monetary balances with last-write-wins; recompute balances from authorized ledger entries.

## Workflow C — Payment and customer balance
- Invoice adds a charge to the customer ledger.
- Customer payment reduces total outstanding balance irrespective of invoice selection.
- Credit/refund/discount is a separate auditable entry, with reason, actor, and timestamp.
- Duplicate `operation_id` must not double-apply a payment.
- Use decimal/integer minor units consistently and test rounding.
- Define whether a customer with negative balance has a carried credit.

## Workflow D — Supabase security
- Enable and test Row Level Security for each tenant-owned table.
- Avoid using service-role keys in Flutter or desktop builds.
- Use trusted functions/Edge Functions for sensitive actions such as activation and privileged ledger writes.
- Validate webhook signatures and verify payment server-side; do not trust success redirects.
- For offline access, define device authorization and local protection clearly.

## Workflow E — Platform release
**Android:** release signing, compatible APK/AAB, install/update testing, backup/data migration tests.

**iOS:** requires macOS/Xcode for builds, Apple Developer distribution and App Review. External digital purchases/activation may require special App Store compliance review. Validate permissions and background-task limitations.

**Windows:** package installer (e.g., Inno Setup/MSIX), native runtime requirements, Windows Defender/SmartScreen considerations, tested installer and update channel.

**macOS/Linux:** verify dependent plugins and packaging per platform, rather than assuming mobile plugins work identically.

## Recommended test matrix
| Case | Expected outcome |
|---|---|
| Offline new invoice | Visible immediately, queued, survives restart |
| Offline customer payment | Balance updates once locally |
| Retry same payment N times | Applied once on server |
| Two devices edit record | Conflict resolved explicitly |
| Offline delete followed by sync | Tombstone propagated safely |
| Connectivity reports network but server unavailable | Queue preserved and retried |
| Backup while offline | Local backup possible; cloud sync pending shown |
| New schema after upgrade | Old data migrated without loss |

## Done report template
- **Changed:** features/files and why.
- **Data migration:** required or not, and rollback considerations.
- **Verification:** commands/tests actually run.
- **Platforms:** tested vs untested.
- **Risks:** outstanding issues and next practical action.

## Execution gates and dependency protection
- Read `docs/DEVELOPMENT_PLAN.md` and follow only the user-approved phase.
- Inspect `pubspec.yaml` and `pubspec.lock` before importing packages; never add/remove/update dependencies or change either file without a distinct, explicit user-approved dependency task.
- If missing a required package, provide the blocker and an installed-package workaround, then wait for approval.
- On every phase handoff, report validation results and verify both manifests are unchanged.
