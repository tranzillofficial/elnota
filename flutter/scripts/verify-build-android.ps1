param(
  [Parameter(Mandatory = $true)][string]$Flutter,
  [Parameter(Mandatory = $true)][string]$AndroidSdk,
  [Parameter(Mandatory = $true)][string]$JavaHome,
  [string]$Version = '1.0.6',
  [int]$BuildNumber = 2007
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Push-Location $projectRoot
try {
  if (-not (Test-Path -LiteralPath 'android/key.properties')) {
    throw 'Original release signing configuration is required.'
  }
  $env:JAVA_HOME = $JavaHome
  $env:ANDROID_HOME = $AndroidSdk
  $env:ANDROID_SDK_ROOT = $AndroidSdk
  $flutterRoot = Split-Path (Split-Path $Flutter -Parent) -Parent
  [IO.File]::WriteAllLines((Join-Path $projectRoot 'android/local.properties'), @(
    "sdk.dir=$($AndroidSdk.Replace('\', '/'))",
    "flutter.sdk=$($flutterRoot.Replace('\', '/'))"
  ))
  & $Flutter pub get --enforce-lockfile
  if ($LASTEXITCODE -ne 0) { throw 'Dependency verification failed.' }
  & $Flutter analyze --no-pub
  if ($LASTEXITCODE -ne 0) { throw 'Static analysis failed.' }
  & $Flutter test --no-pub --concurrency=1
  if ($LASTEXITCODE -ne 0) { throw 'Flutter tests failed.' }
  & $Flutter build apk --release --target-platform android-arm,android-arm64 --no-pub "--build-name=$Version" "--build-number=$BuildNumber" --dart-define=ENABLE_ADMIN_WRITES=true --dart-define=ENABLE_RELATIONAL_SYNC=true --dart-define=ENABLE_V2_CLOUD_BACKUP=true
  if ($LASTEXITCODE -ne 0) { throw 'Android release build failed.' }
  Write-Output "Verified release APK: $projectRoot/build/app/outputs/flutter-apk/app-release.apk"
} finally {
  Pop-Location
}
