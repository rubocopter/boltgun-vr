$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$sandbox = Join-Path $repo ('build\reinstall-backup-check-' + [guid]::NewGuid().ToString('N'))
$profile = Join-Path $sandbox 'profile'
$game = Join-Path $sandbox 'game'
$steam = Join-Path $sandbox 'steam'
$launcher = Join-Path $sandbox 'launcher'
$output = Join-Path $sandbox 'snapshots'

function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Write-Fixture([string]$Root, [string]$Relative, [string]$Content) {
    $path = Join-Path $Root $Relative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null
    [IO.File]::WriteAllText($path, $Content)
}

Write-Fixture $profile 'config.txt' 'local-uevr-config'
Write-Fixture $profile 'data\bolter3d.settings' 'calibration=custom'
Write-Fixture $profile 'data\chainsword3d.mode' 'preview'
Write-Fixture $profile 'scripts\boltgun_bolter3d.lua' 'script-v15'
Write-Fixture $profile 'plugins\boltgun_muzzle.dll' 'test-only-not-real-dll'
Write-Fixture $profile 'crash.dmp' 'private-dump'
Write-Fixture $profile 'log.txt' 'private-log'
Write-Fixture $profile 'data\pause.status' 'transient'
Write-Fixture $game 'Engine.ini' 'local-ini'
Write-Fixture $game 'Input.ini' 'local-input'
Write-Fixture $steam 'steam.app.2005010_oculus_touch_2_binding.json' '{"binding":1}'
Write-Fixture $steam 'steam.app.123456_oculus_touch_2_binding.json' '{"unrelated":1}'
Write-Fixture $launcher 'launcher.json' '{"uevrInjectorPath":"D:\\UEVR\\UEVRInjector.exe"}'

& (Join-Path $repo 'tools\Backup-Reinstall.ps1') -ProfileRoot $profile -GameConfigRoot $game -SteamBindingRoot $steam -SettingsRoot $launcher -OutputRoot $output -SnapshotName test
$snapshot = Join-Path $output 'test'
$manifest = Get-Content -LiteralPath (Join-Path $snapshot 'manifest.json') -Raw | ConvertFrom-Json
Assert ($manifest.version -eq 1) 'Snapshot manifest version missing.'

foreach ($file in $manifest.files) {
    $path = Join-Path $snapshot (Join-Path $file.area $file.relativePath)
    Assert (Test-Path -LiteralPath $path -PathType Leaf) "Missing snapshot file: $path"
    Assert ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -eq $file.sha256) "Bad SHA-256: $path"
}
foreach ($expected in @(
    'uevr-profile\config.txt', 'uevr-profile\data\bolter3d.settings',
    'uevr-profile\plugins\boltgun_muzzle.dll', 'game-config\Engine.ini',
    'steam-bindings\steam.app.2005010_oculus_touch_2_binding.json',
    'launcher-settings\launcher.json'
)) {
    Assert (Test-Path -LiteralPath (Join-Path $snapshot $expected)) "Expected $expected"
}
foreach ($excluded in @('uevr-profile\crash.dmp','uevr-profile\log.txt','uevr-profile\data\pause.status','steam-bindings\steam.app.123456_oculus_touch_2_binding.json')) {
    Assert (-not (Test-Path -LiteralPath (Join-Path $snapshot $excluded))) "Unexpected $excluded"
}

$rejected = $false
try {
    & (Join-Path $repo 'tools\Backup-Reinstall.ps1') -ProfileRoot $profile -GameConfigRoot $game -SteamBindingRoot $steam -SettingsRoot $launcher -OutputRoot $output -SnapshotName test | Out-Null
} catch { $rejected = $true }
Assert $rejected 'Existing snapshot was silently overwritten.'
Assert ([IO.File]::ReadAllText((Join-Path $profile 'config.txt')) -eq 'local-uevr-config') 'Source profile changed.'
Write-Output "Reinstall backup test passed: inventory, hashes, exclusions, duplicate protection and untouched sources. $sandbox"
