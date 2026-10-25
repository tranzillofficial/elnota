# Bundled web database assets
- `drift_worker.js`: copied from the already resolved `drift` 2.35.2 package.
- `sqlite3.wasm`: matching sqlite3.dart 3.5.2 release artifact:
  https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-3.5.2/sqlite3.wasm
These are runtime assets, not new Dart package dependencies.
Serve on HTTPS with correct WASM MIME type and the isolation headers in `_headers`.
Translate those headers into your hosting provider's configuration if it does
not support this format. The web app is not the public marketing landing.
