$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
function Assert-Hash([string]$RelativePath, [string]$Expected) {
    $path = Join-Path $repo $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing source: $RelativePath. Run tools/Build.ps1 for native plugins." }
    if ((Get-FileHash -LiteralPath $path).Hash -ne $Expected) { throw "SHA-256 mismatch: $RelativePath" }
}
foreach ($entry in (Get-Content -LiteralPath (Join-Path $repo 'deployment.json') -Raw | ConvertFrom-Json)) {
    Assert-Hash $entry.source $entry.sha256
    if ($entry.backup) { Assert-Hash $entry.backup $entry.originalSha256 }
}
$bolter = Get-Content -LiteralPath (Join-Path $repo 'manifests\bolter3d.package.json') -Raw | ConvertFrom-Json
Assert-Hash $bolter.source $bolter.sha256
Assert-Hash $bolter.settingsSource $bolter.settingsSha256
Assert-Hash $bolter.pluginSource $bolter.pluginSha256
$chain = Get-Content -LiteralPath (Join-Path $repo 'manifests\chainsword3d.package.json') -Raw | ConvertFrom-Json
foreach ($file in $chain.files) { Assert-Hash $file.source $file.sha256 }
Write-Output 'All deployment and package source hashes match.'
