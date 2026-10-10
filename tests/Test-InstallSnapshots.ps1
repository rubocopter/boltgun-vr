# Snapshot restoration tests use only isolated fixture destinations.
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$sandbox=Join-Path $repo ('build\install-snapshot-check-'+[guid]::NewGuid().ToString('N'))
$profile=Join-Path $sandbox 'profile'
$game=Join-Path $sandbox 'game'
$steam=Join-Path $sandbox 'steam'
$backups=Join-Path $sandbox 'backups'

function Assert([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Reject([scriptblock]$Action,[string]$Message) {
    $caught=$false
    try { & $Action | Out-Null } catch { $caught=$true }
    Assert $caught $Message
}
function Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }

New-Item -ItemType Directory -Path $profile,$game,$steam -Force | Out-Null
# A recognised existing input must survive restoration byte for byte.
$ini=Join-Path $game 'Engine.ini'
Copy-Item -LiteralPath (Join-Path $repo 'game-config\Engine.ini') -Destination $ini
$originalIni=Hash $ini
# Optional content already present before setup belongs to the user.
$optionalScript=Join-Path $profile 'scripts\boltgun_bolter3d.lua'
New-Item -ItemType Directory -Path (Split-Path -Parent $optionalScript) -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $repo 'src\lua\boltgun_bolter3d.lua') -Destination $optionalScript
$originalOptionalHash=Hash $optionalScript
$optionalMode=Join-Path $profile 'data\bolter3d.mode'
New-Item -ItemType Directory -Path (Split-Path -Parent $optionalMode) -Force | Out-Null
[IO.File]::WriteAllText($optionalMode,'custom-original-mode')
$params=@{ProfileRoot=$profile;GameConfigRoot=$game;SteamBindingRoot=$steam;BackupRoot=$backups}

& (Join-Path $repo 'scripts\Install.ps1') @params | Out-Null
. (Join-Path $repo 'tools\Snapshots.ps1')
$snapshot=Get-BoltgunSnapshotPath -RepositoryRoot $repo -ProfileRoot $profile -GameConfigRoot $game -BackupRoot $backups
$manifestPath=Join-Path $snapshot 'manifest.json'
Assert (Test-Path -LiteralPath $manifestPath -PathType Leaf) 'Pre-install snapshot missing.'
$manifestHash=Hash $manifestPath
$manifest=Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$engineRecord=@($manifest.entries | Where-Object { $_.target -eq $ini })[0]
Assert ($engineRecord.existed -and $engineRecord.sha256 -eq $originalIni) 'Existing INI not captured.'
Assert ($manifest.version -eq 2) 'Optional files missing from snapshot schema.'
Assert ((@($manifest.entries | Where-Object { $_.target -eq $optionalScript })[0]).sha256 -eq $originalOptionalHash) 'Existing optional script not captured.'
$config=Join-Path $profile 'config.txt'
Assert ((@($manifest.entries | Where-Object { $_.target -eq $config })[0]).existed -eq $false) 'Empty profile state not recorded.'

# Reinstall may refresh deployed files, but cannot overwrite the original snapshot.
& (Join-Path $repo 'scripts\Install.ps1') @params | Out-Null
Assert ((Hash $manifestPath) -eq $manifestHash) 'Repeated install overwrote snapshot.'

$beforeConfig=Hash $config
[IO.File]::WriteAllText($config,'foreign-edits-must-survive')
Reject { & (Join-Path $repo 'scripts\Restore.ps1') @params } 'Unknown modified install accepted for restore.'
Assert ([IO.File]::ReadAllText($config) -eq 'foreign-edits-must-survive') 'Unknown user edits removed.'
Assert ((Hash $ini) -eq $originalIni) 'Rejected restoration touched another file.'
Copy-Item -LiteralPath (Join-Path $repo 'profile\config.txt') -Destination $config -Force
Assert ((Hash $config) -eq $beforeConfig) 'Test setup could not restore package bytes.'

# An invalid backup must abort before changing any destination.
$backupIni=Join-Path $snapshot $engineRecord.file
$validCopy=[IO.File]::ReadAllBytes($backupIni)
[IO.File]::WriteAllText($backupIni,'corrupt snapshot')
Reject { & (Join-Path $repo 'scripts\Restore.ps1') @params } 'Corrupted snapshot accepted.'
Assert (Test-Path -LiteralPath $config) 'Corrupt snapshot modified installed files.'
[IO.File]::WriteAllBytes($backupIni,$validCopy)

Move-Item -LiteralPath $manifestPath -Destination ($manifestPath+'.missing')
Reject { & (Join-Path $repo 'scripts\Restore.ps1') @params } 'Missing snapshot manifest accepted.'
Assert (Test-Path -LiteralPath $config) 'Missing snapshot modified installed files.'
Move-Item -LiteralPath ($manifestPath+'.missing') -Destination $manifestPath

# Future package revisions may reorder enabled and optional sources. Restoring
# an existing snapshot must still match each destination to its own record.
$reorderedRoot=Join-Path $sandbox 'reordered-package'
New-Item -ItemType Directory -Path (Join-Path $reorderedRoot 'scripts'),(Join-Path $reorderedRoot 'tools') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $repo 'scripts\Restore.ps1') -Destination (Join-Path $reorderedRoot 'scripts')
Copy-Item -LiteralPath (Join-Path $repo 'tools\Paths.ps1') -Destination (Join-Path $reorderedRoot 'tools')
Copy-Item -LiteralPath (Join-Path $repo 'tools\Snapshots.ps1') -Destination (Join-Path $reorderedRoot 'tools')
$originalEntries=@(Get-Content -LiteralPath (Join-Path $repo 'deployment.json') -Raw | ConvertFrom-Json)
$reorderedEntries=@($originalEntries | Where-Object { $_.disabled }) + @($originalEntries | Where-Object { -not $_.disabled })
[IO.File]::WriteAllText((Join-Path $reorderedRoot 'deployment.json'),
    (($reorderedEntries | ConvertTo-Json -Depth 8)+"`n"),[Text.UTF8Encoding]::new($false))
& (Join-Path $reorderedRoot 'scripts\Restore.ps1') @params | Out-Null
Assert (-not (Test-Path -LiteralPath $config)) 'Reordered restore kept an initially absent active file.'
Assert ((Hash $ini) -eq $originalIni) 'Reordered restore did not recover existing INI.'
Assert ((Hash $optionalScript) -eq $originalOptionalHash) 'Reordered restore changed existing optional script.'
Assert ([IO.File]::ReadAllText($optionalMode) -eq 'custom-original-mode') 'Reordered restore changed existing optional setting.'

& (Join-Path $repo 'scripts\Restore.ps1') @params | Out-Null
Assert (-not (Test-Path -LiteralPath $config)) 'Initially absent file was not removed.'
Assert ((Hash $ini) -eq $originalIni) 'Existing INI was not restored exactly.'
Assert (-not (Test-Path -LiteralPath (Join-Path $game 'Input.ini'))) 'Initially absent game INI survived.'
Assert ((Hash $optionalScript) -eq $originalOptionalHash) 'Pre-existing optional script was removed.'
Assert ([IO.File]::ReadAllText($optionalMode) -eq 'custom-original-mode') 'Pre-existing optional setting was removed.'

# Reinstalling after a restore still uses the first pre-install snapshot.
& (Join-Path $repo 'scripts\Install.ps1') @params | Out-Null
Assert ((Hash $manifestPath) -eq $manifestHash) 'Snapshot replaced after restoration.'
& (Join-Path $repo 'scripts\Restore.ps1') @params | Out-Null
Assert (-not (Test-Path -LiteralPath $config)) 'Second restore did not recover absence.'
Write-Output "Install snapshot checks passed: existing/absent, repeated install, unknown edits, corrupt/missing backup and second restore. $sandbox"
