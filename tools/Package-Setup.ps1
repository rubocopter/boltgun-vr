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
$allowedDirs=@('profile','game-config','assets','manifests','src\lua')
$rootFiles=@('README.md','deployment.json','Instalar Boltgun VR.cmd','Jugar Boltgun VR.cmd')
$scriptFiles=@('Install.ps1','Restore.ps1','Setup-BoltgunVR.ps1',
    'Play-BoltgunVR.ps1','Bolter3D.ps1','Chainsword3D.ps1','Comprobar-perfil.ps1')

try {
    New-Item -ItemType Directory -Path $staging -Force | Out-Null
    foreach ($directory in $allowedDirs) {
        $from=Join-Path $repo $directory
        $to=Join-Path $staging $directory
        New-Item -ItemType Directory -Path (Split-Path -Parent $to) -Force | Out-Null
        Copy-Item -LiteralPath $from -Destination $to -Recurse
    }
    # Include published guides and their linked revision history. Exclude
    # private work notes and the internal repository-preparation archive.
    New-Item -ItemType Directory -Path (Join-Path $staging 'docs') -Force | Out-Null
    Get-ChildItem -LiteralPath (Join-Path $repo 'docs') -Filter '*.md' -File |
        ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $staging 'docs') }
    New-Item -ItemType Directory -Path (Join-Path $staging 'docs\history') -Force | Out-Null
    foreach ($revision in 12..15) {
        $name="2026-10-09-revision$revision.md"
        Copy-Item -LiteralPath (Join-Path $repo "docs\history\$name") -Destination (Join-Path $staging 'docs\history')
    }
    New-Item -ItemType Directory -Path (Join-Path $staging 'build\plugins') -Force | Out-Null
    foreach ($plugin in @('boltgun_muzzle.dll','boltgun_chainsword.dll')) {
        Copy-Item -LiteralPath (Join-Path $repo "build\plugins\$plugin") -Destination (Join-Path $staging 'build\plugins')
    }
    foreach ($item in $rootFiles) {
        Copy-Item -LiteralPath (Join-Path $repo $item) -Destination (Join-Path $staging $item)
    }
    New-Item -ItemType Directory -Path (Join-Path $staging 'scripts') -Force | Out-Null
    foreach ($name in $scriptFiles) {
        Copy-Item -LiteralPath (Join-Path $repo "scripts\$name") -Destination (Join-Path $staging 'scripts')
    }
    New-Item -ItemType Directory -Path (Join-Path $staging 'tools') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repo 'tools\Paths.ps1') -Destination (Join-Path $staging 'tools')
    Copy-Item -LiteralPath (Join-Path $repo 'tools\Check-Repository.ps1') -Destination (Join-Path $staging 'tools')
    Copy-Item -LiteralPath (Join-Path $repo 'tools\Snapshots.ps1') -Destination (Join-Path $staging 'tools')

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
