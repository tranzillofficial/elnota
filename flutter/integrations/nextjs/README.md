# Landing and release integration

The old `tranzillofficial/elnota` repository was READ ONLY. No files, branches,
settings, deployments, or production records in that project were changed.
Its `app/page.tsx` is a server-rendered marketing landing; preserve that route,
its metadata, sitemap, articles, and canonical `https://elnota.shop`.

## Origins
- `https://elnota.shop`: existing Next.js landing and public content.
- `https://app.elnota.shop`: separate Flutter build, app routes, noindex.
- `https://downloads.elnota.shop`: versioned public release artifacts and hashes.

Subdomain separation avoids the existing Next/PWA service worker controlling the
Flutter app or its cache. Do not rewrite `/` to Flutter or load Flutter in the
landing HTML. A QR code is an authentication challenge, not an SEO strategy.

## Ready-to-integrate landing section
`DownloadsSection.tsx` and its CSS module are prepared in this NEW repository.
After the old-repository restriction is lifted, copy both into that landing's
components folder and render the server component using published release data.
No new npm packages are needed. Do not enable links before the upload is verified.
`distribution/releases.json` intentionally has null URLs until real artifacts
exist. This does not claim installers are already available.

## Builds (local; do not commit credentials)
```powershell
flutter build web --release --no-pub --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...
flutter build apk --release --no-pub --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...
flutter build windows --release --no-pub --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...
# Inno Setup 6 (separate build tool, not a Flutter dependency):
ISCC.exe /DAppVersion=1.0.0 distribution/windows/elnota.iss
./scripts/stage-releases.ps1 -Version 1.0.0
```
Use private signing configuration for Android; never publish a debug-signed APK.
Authenticode signing for the Windows installer must be configured in release CI.
Flutter has no supported Windows x86/32-bit build. Offer the web app to those
users; never relabel an x64 binary as 32-bit. Validate browser support separately.

## QR deployment prerequisites
Review `docs/DEVICE_LOGIN.md`, deploy the additive pairing migration and Edge
Function to a staging project first, test expiration/replay/origin restrictions,
and then configure the new app host. No cloud SQL or deployment was executed by
this change. The existing cloud ledger uses JSON documents, while the new
Flutter app uses relational local data; full shared-ledger synchronization is
still a separate compatibility project. Pairing does not migrate the old data.
