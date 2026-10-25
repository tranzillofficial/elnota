#!/usr/bin/env bash
set -euo pipefail

# The preview supplies only public Auth client values. No ledger write flags.
# Relational sync stays disabled. Admin actions require server-verified admin permission.
if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_PUBLISHABLE_KEY:-}" ]]; then
  echo 'Preview Supabase URL and publishable key are required.' >&2
  exit 1
fi
sdk_dir="${TMPDIR:-/tmp}/elnota-flutter-3.47.7"
if [[ ! -x "$sdk_dir/bin/flutter" ]]; then
  git clone --depth 1 --branch 3.47.7 https://github.com/flutter/flutter.git "$sdk_dir"
fi
export PATH="$sdk_dir/bin:$PATH"
flutter config --no-analytics
flutter pub get --enforce-lockfile
flutter build web --release --no-pub --build-name=1.0.4 --build-number=2005 \
  --no-wasm-dry-run \
  --dart-define=ENABLE_ADMIN_WRITES=true \
  --dart-define="SUPABASE_URL=$SUPABASE_URL" \
  --dart-define="SUPABASE_PUBLISHABLE_KEY=$SUPABASE_PUBLISHABLE_KEY"
mkdir -p build/site
cp -a build/web/. build/site/
flutter build web --release --no-pub --build-name=1.0.4 --build-number=2005 --no-wasm-dry-run \
  --base-href=/demo/ --dart-define=ELNOTA_DEMO=true
mkdir -p build/site/demo
cp -a build/web/. build/site/demo/
