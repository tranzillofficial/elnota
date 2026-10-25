param(
  [Parameter(Mandatory=$true)][string]$Version,
  [Parameter(Mandatory=$true)][int]$BuildNumber,
  [string]$Flutter = 'flutter'
)
$ErrorActionPreference = 'Stop'
if ($Version -notmatch '^\d+\.\d+\.\d+$' -or $BuildNumber -lt 1) {
  throw 'Supply a valid version and increasing base build number.'
}
if (-not (Test-Path -LiteralPath 'android/key.properties')) {
  throw 'Release signing configuration is required. Debug signing is not permitted.'
}
# Shared public BackendConfig is compiled into every platform; no private key is used.
& $Flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64 --no-pub "--build-name=$Version" "--build-number=$BuildNumber" --dart-define=ENABLE_ADMIN_WRITES=true --dart-define=ENABLE_RELATIONAL_SYNC=true --dart-define=ENABLE_V2_CLOUD_BACKUP=true
if ($LASTEXITCODE -ne 0) { throw 'Android release build failed.' }
