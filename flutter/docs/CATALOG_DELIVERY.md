# Catalog and access implementation

Implemented in elnotaapp only. No old repository or live Supabase schema/data
was changed. The new SQL migration is staged and has not been applied.

- Local schema v3 adds categories/products with text barcodes, exact prices,
  optional description and WebP thumbnails. Active barcode/category uniqueness,
  transaction/outbox atomicity, soft archive and populated-category checks are
  enforced locally. Existing financial records remain unchanged.
- Account-specific SQLite/IndexedDB is the persistent cache. Basic account data
  stays independent per device/browser profile. Catalog access requires active
  cloud membership or a separately administered catalog override.
- Server-owned account entitlements cache per user for offline operation.
  The staged override table uses RLS and a protected admin RPC. The admin UI
  exposes a catalog-only exception, behind the existing default-off write gate.
- Images use imcodec 0.5.5: JPG/PNG/WebP input, at most 10MiB and 24M pixels;
  WebP output is resized to at most 960px and bounded to 512KiB. No cloud upload
  occurs when selecting a product photo.
- Web defaults to email/password login with optional QR. Mobile settings open
  mobile_scanner 7.4.2; only valid ElNota pairing challenges are accepted, then
  the existing comparison/approval screen is shown. Physical camera/pairing
  verification is still required on a configured test backend and device.
- Customer add/edit uses the shared centered frame with validation and busy/
  load-error handling. GetX toasts and Material snackbars have bounded desktop
  width; existing broad Get.snackbar calls were routed through AppToast.

Daily backup preparation stores the completed day per account, checks midnight
while running, and retries on reconnect/resume. Upload is cloud-only, checks a
fresh server entitlement and account identity, and uses a separate v2 backup
namespace. Its feature flag remains off. Closed apps/OS scheduling at exactly
midnight are not implemented or verified; browser tabs cannot guarantee this.

Backup snapshots are not a multi-device merge protocol. Cross-device ledger
sync, legacy JSON conversion, server-side staging tests, scheduled background
execution and production customer migration remain separate unfinished work.
Nothing in this delivery enables them on the current production database.

Dependency changes were explicitly approved: mobile_scanner and imcodec, plus
its transitive zcodec. Excel/image/archive versions already in the project were
preserved after detecting their incompatible newer-image constraints.

Verification: all 68 Flutter tests passed, including real SQLite migration,
atomic catalog writes, duplicate barcode rollback, WebP decoding/limits,
entitlement expiration and phone/desktop widgets. A later focused rerun of the
four catalog/customer-form widget checks passed after form loading refinements.
`flutter analyze --no-pub lib test` reported no issues. A JavaScript Flutter Web
release build succeeded. No physical-device camera, closed-app midnight job,
live feature-override RPC or cloud-backup upload was exercised.
