# ElNota | Architecture

> Status: Proposed architecture, not an assertion about the existing codebase. Validate against real code before implementation.

## Goals and scope
- Flutter for Android, iOS and desktop (Windows first; macOS/Linux after platform-specific validation).
- Arabic-first RTL interface, adaptable desktop layouts and responsive mobile screens.
- Offline-first accounting; normal reads/writes work without a network connection.
- GetX for state, dependency injection and routes; Drift/SQLite for durable on-device data; Supabase for identity and cloud synchronization.
- No loss, duplication, or silent reinterpretation of financial records.

## Folder layout
```text
lib/
  app/
    bindings/ routes/ theme/
  core/
    database/      # drift tables, migrations, DAOs
    network/       # Supabase client, connectivity and API adapters
    sync/          # queue, cursor, push/pull, conflicts
    services/      # backup, printing, export, secure storage
    utils/ widgets/
  features/
    auth/ customers/ invoices/ payments/
    installments/ products/ reports/ settings/
  main.dart
```
Per feature (only create what's needed): `bindings/`, `controllers/`, `models/`, `repositories/`, `views/`, `views/widgets/`, optional `services/`.

## Dependency direction
`View -> GetX Controller -> Repository / Application Service -> Drift DAO`.
A separately scheduled `SyncEngine <-> Supabase` exchanges validated changes with Drift. Controllers **must not** directly access Supabase or database tables. Use application services for cross-feature financial workflows and transactions.

## Source of truth
- Drift is the **local UI/read and write source** while the app runs, even offline.
- Supabase PostgreSQL is the **authoritative shared state after reconciliation**, NOT a direct replacement for local UI reads.
- Every mutation persists the domain change and an outbox entry in **one SQLite transaction**.
- Push/pull apply server results back into Drift atomically; UI uses `watch()` streams to refresh GetX observable state.

## State and lifecycle
- `GetMaterialApp`, named routes, route-scoped `Bindings` and `Get.lazyPut` for feature controllers.
- Initialize database/auth/sync core once; dispose workers/subscriptions/controllers appropriately.
- Avoid `permanent: true` for per-screen controllers; cancel stream subscriptions on `onClose`.
- Separate `loading`, `empty`, `error`, `offline`, and `syncPending` statuses.

## Financial boundaries
- Store monetary amounts as integer **minor units** (e.g., piasters) or exact decimal strings end to end; don't use floating point.
- All money-changing operations (invoice, payment, discount, reversal) happen via validated domain methods and database transactions.
- Multi-device disputes use server-confirmed immutable operations, not blind last-write-wins for money.

## Cross-platform constraints
- Background periodic work is best effort, especially on iOS; sync on launch/resume, connection recovery and after writes.
- Windows printing and installer packaging need separate smoke tests; native plugin support must be verified on each target platform.
- iOS distribution requires signing/Xcode/macOS build environment. Never assume Android plugins work on desktop.

## Definition of done
- `dart format`, `flutter analyze`, unit/widget tests and sync integration tests pass.
- Offline operations, app restart, reconnect, concurrent writers, auth expiry and forced retries tested.
- Any new table includes SQLite and Supabase migration, RLS policy where appropriate, and rollback/recovery notes.
- Update the relevant `docs/*.md` when changing a contract; note unresolved assumptions instead of inventing business rules.
