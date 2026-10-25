param(
  [Parameter(Mandatory = $true)][string]$Version,
  [string]$BaseUrl = 'https://downloads.elnota.shop',
  [string]$OutputDirectory = (Join-Path $PSScriptRoot '../distribution/artifacts')
)
$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$outputRoot = [System.IO.Path]::GetFullPath($OutputDirectory)
if (-not $outputRoot.StartsWith($projectRoot + [System.IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Release output must stay inside the project.' }
if ($Version -notmatch '^\d+\.\d+\.\d+([+-][A-Za-z0-9.-]+)?$') { throw 'Invalid version.' }
if (-not $BaseUrl.StartsWith('https://')) { throw 'Downloads require HTTPS.' }
New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
$manifest = @{ site='https://elnota.shop'; webApp='https://app.elnota.shop'; android=$null; windowsX64=$null; windowsX86=@{ supported=$false; alternative='https://app.elnota.shop' } }
$targets = @(
  @{ key='android'; source=(Join-Path $projectRoot 'build/app/outputs/flutter-apk/app-release.apk'); name="elnota-$Version-android.apk" },
  @{ key='windowsX64'; source=(Join-Path $projectRoot "distribution/windows/output/ElNota-$Version-windows-x64.exe"); name="ElNota-$Version-windows-x64.exe" }
)
foreach ($target in $targets) {
  if (Test-Path -LiteralPath $target.source -PathType Leaf) {
    $destination = Join-Path $outputRoot $target.name
    Copy-Item -LiteralPath $target.source -Destination $destination
    $file = Get-Item -LiteralPath $destination
    $manifest[$target.key] = @{ version=$Version; url=($BaseUrl.TrimEnd('/') + '/' + $target.name); sha256=(Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant(); size=$file.Length }
  }
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $outputRoot 'releases.json') -Encoding utf8
Write-Output 'Release files staged locally. Publish artifacts before enabling these URLs on the landing.'
