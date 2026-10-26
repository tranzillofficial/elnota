param(
  [Parameter(Mandatory = $true)][string]$Apk,
  [Parameter(Mandatory = $true)][string]$BuildTools,
  [string]$Package = 'shop.elnota.app',
  [string]$Version = '1.0.6',
  [int]$BuildNumber = 2007,
  [string]$CertificateSha256 = '57a1b4fb436e47b9a1a99d310c559753cf67bdd1964e0a69da4eb81fb871c935'
)
$ErrorActionPreference = 'Stop'
$apkFile = Get-Item -LiteralPath $Apk
$signatures = & (Join-Path $BuildTools 'apksigner.bat') verify --verbose --print-certs $apkFile.FullName
if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed.' }
$signatureText = $signatures -join "`n"
if ($signatureText -notmatch "certificate SHA-256 digest: $CertificateSha256") {
  throw 'APK was not signed with the expected release certificate.'
}
$badging = & (Join-Path $BuildTools 'aapt.exe') dump badging $apkFile.FullName
if ($LASTEXITCODE -ne 0) { throw 'Cannot read APK metadata.' }
$metadata = $badging -join "`n"
foreach ($expected in @("name='$Package'", "versionCode='$BuildNumber'", "versionName='$Version'", "sdkVersion:'24'", "android.permission.INTERNET", "launchable-activity: name='com.example.elnota.MainActivity'")) {
  if (-not $metadata.Contains($expected)) { throw "Missing expected APK metadata: $expected" }
}
if ($metadata.Contains('application-debuggable')) { throw 'APK must not be debuggable.' }

$archive = [IO.Compression.ZipFile]::OpenRead($apkFile.FullName)
try {
  $names = @($archive.Entries.FullName)
  foreach ($abi in @('armeabi-v7a', 'arm64-v8a')) {
    foreach ($library in @('libflutter.so', 'libapp.so')) {
      if ($names -notcontains "lib/$abi/$library") { throw "Missing $abi/$library" }
    }
  }
  $requiredClasses = @(
    'Lcom/example/elnota/MainActivity;',
    'Lio/flutter/plugins/GeneratedPluginRegistrant;',
    # This stable channel survives R8 renaming the Java implementation class.
    'plugins.it_nomads.com/flutter_secure_storage'
  )
  $foundClasses = @{}
  foreach ($entry in $archive.Entries | Where-Object { $_.FullName -match '^classes\d*\.dex$' }) {
    $reader = [IO.StreamReader]::new($entry.Open(), [Text.Encoding]::Latin1)
    try { $dex = $reader.ReadToEnd() } finally { $reader.Dispose() }
    foreach ($class in $requiredClasses) {
      if ($dex.Contains($class)) { $foundClasses[$class] = $true }
    }
  }
  foreach ($class in $requiredClasses) {
    if (-not $foundClasses[$class]) { throw "Required Android entry point or auth plugin missing: $class" }
  }
} finally {
  $archive.Dispose()
}
[ordered]@{
  file = $apkFile.FullName
  package = $Package
  version = $Version
  versionCode = $BuildNumber
  minimumAndroidApi = 24
  architectures = @('armeabi-v7a', 'arm64-v8a')
  bytes = $apkFile.Length
  sha256 = (Get-FileHash -LiteralPath $apkFile.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
  certificateSha256 = $CertificateSha256
  debuggable = $false
  nativeEntryPointsVerified = $true
} | ConvertTo-Json -Depth 3
