# ElNota — Four-Phase Development Plan

> Planning document; not evidence that any stage is implemented. **Current phase: 1 (proposed; implementation awaits user's explicit approval).** Only user approval changes the active phase.

## Universal working protocol
1. Read `AGENTS.md`, this plan, the relevant docs, existing source, `pubspec.yaml` and `pubspec.lock` before implementation.
2. Record installed direct dependencies and resolved versions in a **report**, not by changing manifests. Assess plugin platform support for Android, iOS, Windows (and macOS/Linux if requested).
3. Freeze `pubspec.yaml` and `pubspec.lock`: no changes, no package commands that rewrite either file. If a package is missing, present available alternatives and wait for explicit user permission for a separate dependency task.
4. Before each coding session declare: active phase, allowed files/features, intended acceptance tests and known blockers.
5. Avoid destructive migrations or modifying live Supabase infrastructure without a reviewed plan and authorization.
6. Validate with available non-mutating commands; do not claim unexecuted tests. At phase end show test results, outstanding work and `git diff -- pubspec.yaml pubspec.lock` status.
7. Stop after the phase and ask for authorization for the next one.

## Phase 1 — Foundation & architecture
**Goal:** establish reliable scaffolding without shipping unfinished accounting/sync features.

**Scope**
- Audit project, packages, SDK, app entrypoint, existing files, platform plugins, schemas and docs.
- Establish `app/`, `core/`, `features/` feature-first layout using GetX bindings and routes.
- Configure reusable design tokens, Arabic/RTL, responsive desktop/mobile navigation, input primitives and loading/empty/error UI states.
- Define Drift tables, migration/version strategy, tenant boundaries and sync-outbox contract; initialize local persistence **only with installed packages**.
- Define repository contracts and test approach; add small demonstrable smoke tests where tooling allows.

**Acceptance**
- Existing behavior not broken; demo route/UI can run on supported target.
- `flutter analyze` and baseline tests reported honestly; critical errors identified.
- Data and sync design reviewed; no unapproved cloud changes.
- Dependency manifests exactly unchanged.

**Out of scope:** complete ledger flows, production sync, releases.

## Phase 2 — Offline core accounting
**Goal:** fully usable local accounting with correct customer-wide payments.

**Scope**
- Customers; products when required; invoices including manual-amount invoices without line items; customer-wide payments, discounts and adjustments; installments.
- Ledger-based balance calculation in integer minor units or Decimal (depending on installed packages), stable UUIDs, audited reversals.
- Local Drift DAOs/repositories/controllers/views and pending-operation outbox inserted in the same transaction.
- Reports and balance summaries derived from ledger data; validation, backup/export only if already supported.

**Acceptance**
- Create, edit within rules, and query while offline; data persists across restarts.
- One customer payment reduces **aggregate** debt and appears once, not tied to a particular invoice.
- Duplicate operation IDs and interrupted local writes cannot double charge.
- Tested rounding, credits, deletes with unpaid balance, manual invoices and installments.
- No network required for ordinary accounting; dependency manifests unchanged.

**Out of scope:** claiming real multi-device synchronization is complete.

## Phase 3 — Secure cloud sync
**Goal:** converge local and remote data safely with tenant boundaries.

**Scope**
- Supabase Auth + RLS review, scoped server endpoints, tenant isolation, no service role in client.
- Idempotent outbox push, transactional cursor-based pull, tombstones, explicit conflict rules, bounded retries, observability (pending/last success/errors).
- Offline login/session-expiry policy; secure local data and backup strategy; verify existing Supabase schema/migrations before any changes.
- Multi-device scenarios with customer payments and immutable ledger events; manual sync and app-resume recovery.

**Acceptance**
- Reconnect converges data without duplicate payments or losing offline mutations.
- Unauthorized tenant reads/writes rejected; tests for revoked access and session expiry.
- Crash/interruption/retry and page-boundary tests pass; conflicts are surfaced rather than silently overwritten.
- No unapproved production database updates; dependency manifests unchanged.

**Out of scope:** promising periodic background execution at exact times.

## Phase 4 — Hardening & release readiness
**Goal:** prepare production-quality distribution across enabled platforms.

**Scope**
- UX polish for Android/iOS/Windows; keyboard, RTL/accessibility, fast lists, print/PDF/export as permitted by installed packages.
- Unit/widget/integration and migration tests, performance profiling, error telemetry and security checklist.
- Build and packaging verification (Android signed APK/AAB, Windows installer path, iOS macOS/Xcode pipeline when available).
- Version/release notes, upgrade/restore testing and external payment/App Store compliance review.

**Acceptance**
- Critical tests pass or unresolved failures are clearly documented.
- No regression or financial-data-loss scenarios; tested rollback/restore plan.
- Builds reported only if actually produced; no claim of App Store acceptance.
- Dependency manifests unchanged unless independently approved.

## Phase sign-off template
- Phase number / date / explicit approval
- Changes and files touched
- `pubspec.yaml` and `pubspec.lock` diff: **none / discrepancy**
- Commands executed and results; unavailable checks
- Tested platforms
- Unresolved issues, risks, package gaps
- Request approval to begin next phase

## Scope approved by user on 2026-10-23
The current explicit task covers UI implementation, invoice/installment/payment
flows with FIFO allocation, local account statements, settings, a protected
admin dashboard, QR-login preparation and download/landing integration artifacts
inside the NEW elnotaapp repository. This supersedes the stale proposed-phase
header only for that requested scope. It does not authorize changing the old
elnota repository or deploying migrations to the shared production database.

## Catalog and subscription clarification approved 2026-10-23
Add categorized products, barcode/name/category search, optional compressed WebP
images, customer form redesign and bounded desktop toasts. Basic accounts keep
independent device databases. Active cloud accounts may sync/back up; a separate
admin catalog override grants products only, never cloud access. Web supports
password login and optional QR; mobile settings include an in-app scanner.
The user approved mobile_scanner and imcodec (instead of image, which conflicts
with the existing Excel dependency). No other package upgrade was authorized.
Live schema changes, legacy ledger conversion and customer migration remain
outside this local implementation and require isolated staging verification.
