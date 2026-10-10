param(
    [string]$OutputPath=(Join-Path (Split-Path -Parent $PSScriptRoot) 'dist\BoltgunVR-player-local.zip'),
    [switch]$Force
)

$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot

# Package only an explicit player inventory. Never sweep the working tree or
# private backups, extracted game files, UEVR downloads, or unrelated binaries.
& (Join-Path $repo 'tools\Check-Repository.ps1') | Out-Host
$output=[IO.Path]::GetFullPath($OutputPath)
if ((Test-Path -LiteralPath $output) -and -not $Force) {
    throw "Existing ZIP preserved: $output. Choose -OutputPath or specify -Force."
}
$staging=Join-Path $repo ('build\player-package-'+[guid]::NewGuid().ToString('N'))
$rootFiles=@('README.md','deployment.json','Instalar Boltgun VR.cmd','Jugar Boltgun VR.cmd')
$scriptFiles=@('Install.ps1','Restore.ps1','Setup-BoltgunVR.ps1',
    'Play-BoltgunVR.ps1','Bolter3D.ps1','Chainsword3D.ps1','Comprobar-perfil.ps1')
$toolFiles=@('Paths.ps1','Check-Repository.ps1','Snapshots.ps1')
$guideFiles=@('ARCHITECTURE.md','ARSENAL.md','BUILD.md','CHAINSAW.md',
    'CONTROLS.md','EASY-SETUP.md','INSTALACION-FACIL.es.md','INSTALL.md',
    'NATIVE-MUZZLE.md','README.es.md','REINSTALL.md','REPOSITORY.md',
    'SOURCE-AND-NOTICES.md','STATUS.md','TROUBLESHOOTING.md')

# Deployment manifests explicitly select runtime payloads. Everything else
# in the ZIP is listed below, so stray local files are never copied.
$packageFiles=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
function Add-PackageFile([string]$RelativePath) {
    if ([string]::IsNullOrWhiteSpace($RelativePath) -or [IO.Path]::IsPathRooted($RelativePath)) {
        throw "Invalid player package path: $RelativePath"
    }
    $relative=$RelativePath.Replace('/','\')
    $source=[IO.Path]::GetFullPath((Join-Path $repo $relative))
    $repoPrefix=[IO.Path]::GetFullPath($repo).TrimEnd('\')+'\'
    if (-not $source.StartsWith($repoPrefix,[StringComparison]::OrdinalIgnoreCase)) {
        throw "Player package path escapes repository: $RelativePath"
    }
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Missing player package source: $RelativePath"
    }
    [void]$packageFiles.Add($relative)
}
foreach ($name in $rootFiles) { Add-PackageFile $name }
foreach ($name in $scriptFiles) { Add-PackageFile "scripts\$name" }
foreach ($name in $toolFiles) { Add-PackageFile "tools\$name" }
foreach ($name in $guideFiles) { Add-PackageFile "docs\$name" }
foreach ($revision in 12..15) {
    Add-PackageFile "docs\history\2026-10-09-revision$revision.md"
}
foreach ($name in @('bolter3d.package.json','chainsword3d.package.json')) {
    Add-PackageFile "manifests\$name"
}
foreach ($entry in (Get-Content -LiteralPath (Join-Path $repo 'deployment.json') -Raw | ConvertFrom-Json)) {
    Add-PackageFile $entry.source
}
$bolter=Get-Content -LiteralPath (Join-Path $repo 'manifests\bolter3d.package.json') -Raw | ConvertFrom-Json
foreach ($path in @($bolter.source,$bolter.settingsSource,$bolter.pluginSource)) {
    Add-PackageFile $path
}
$chainsword=Get-Content -LiteralPath (Join-Path $repo 'manifests\chainsword3d.package.json') -Raw | ConvertFrom-Json
Add-PackageFile $chainsword.settingsSource
foreach ($entry in $chainsword.files) { Add-PackageFile $entry.source }

try {
    New-Item -ItemType Directory -Path $staging -Force | Out-Null
    foreach ($file in $packageFiles) {
        $to=Join-Path $staging $file
        New-Item -ItemType Directory -Path (Split-Path -Parent $to) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $repo $file) -Destination $to
    }

    # All package inputs are verified once more from inside the staged tree.
    & (Join-Path $staging 'tools\Check-Repository.ps1') | Out-Host
    New-Item -ItemType Directory -Path (Split-Path -Parent $output) -Force | Out-Null
    Compress-Archive -Path (Join-Path $staging '*') -DestinationPath $output -CompressionLevel Optimal -Force:$Force

    Add-Type -AssemblyName System.IO.Compression
    $zip=[IO.Compression.ZipFile]::OpenRead($output)
    try {
        $forbidden=@($zip.Entries | Where-Object {
            $_.FullName -match '(^|/)(UEVRInjector\.exe|\.git|research|backups|diagnostics|previews|superpowers)(/|$)' -or
            $_.FullName -match '\.(exe|pak|pdb|dmp)$'
        })
        if ($forbidden.Count -gt 0) { throw "Unexpected file in package: $($forbidden[0].FullName)" }
    } finally { $zip.Dispose() }
    Write-Output "Local player ZIP: $output"
    Write-Output 'UEVR and game files excluded; no remote or release created.'
} finally {
    if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
}
