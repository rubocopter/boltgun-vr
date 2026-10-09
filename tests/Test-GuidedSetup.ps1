$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$sandbox=Join-Path $repo ('build\guided-setup-check-'+[guid]::NewGuid().ToString('N'))
$zip=Join-Path $sandbox 'player.zip'
$player=Join-Path $sandbox 'player files'
$profile=Join-Path $sandbox 'profile'
$game=Join-Path $sandbox 'game config'
$steam=Join-Path $sandbox 'steam'
$settings=Join-Path $sandbox 'launcher settings'
$fakeInjector=Join-Path $sandbox 'UEVRInjector.exe'

function Assert([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Expect-Rejection([scriptblock]$Action,[string]$Message) {
    $rejected=$false
    try { & $Action | Out-Null } catch { $rejected=$true }
    Assert $rejected $Message
}
New-Item -ItemType Directory -Path $sandbox,$player,$profile,$game,$steam -Force | Out-Null
& (Join-Path $repo 'tools\Package-Setup.ps1') -OutputPath $zip | Out-Null
Expand-Archive -LiteralPath $zip -DestinationPath $player

Add-Type -AssemblyName System.IO.Compression
$archive=[IO.Compression.ZipFile]::OpenRead($zip)
try {
    $names=@($archive.Entries | ForEach-Object { $_.FullName.Replace('\','/') })
    Assert ($names -contains 'build/plugins/boltgun_chainsword.dll') 'Chainsword plugin missing from ZIP.'
    Assert ($names -contains 'build/plugins/boltgun_muzzle.dll') 'Muzzle plugin missing from ZIP.'
    Assert ($names -contains 'Instalar Boltgun VR.cmd') 'Installer shortcut missing.'
    Assert ($names -contains 'scripts/Install.ps1') 'Deployment script missing.'
    Assert ($names -contains 'tools/Snapshots.ps1') 'Restore snapshot tool missing.'
    Assert (@($names | Where-Object { $_ -like '*baseline*' }).Count -eq 0) 'Legacy baseline leaked into package.'
    Assert ($names -contains 'docs/INSTALACION-FACIL.es.md') 'Spanish player instructions missing.'
    Assert ($names -contains 'docs/history/2026-10-09-revision13.md') 'Linked arsenal guide missing.'
    Assert ($names -contains 'docs/history/2026-10-09-revision15.md') 'Linked muzzle diagnostic guide missing.'
    Assert (@($names | Where-Object { $_ -match '(^|/)(superpowers|backups|research|diagnostics|\.git|UEVRInjector\.exe)(/|$)|\.(exe|pak|pdb|dmp)$' }).Count -eq 0) 'Forbidden/private content in player ZIP.'
} finally { $archive.Dispose() }

[IO.File]::WriteAllBytes($fakeInjector,[byte[]]@()) # Test stub, never started.
Copy-Item -LiteralPath (Join-Path $player 'game-config\Engine.ini') -Destination (Join-Path $game 'Engine.ini')

$bindingPath=Join-Path $steam 'steam.app.2005010_oculus_touch_test_binding.json'
$binding=@{bindings=@{'/actions/defaultopenxr'=@{sources=@(@{
    path='/user/hand/left/input/menu';mode='button';
    inputs=@{click=@{output='/actions/defaultopenxr/in/systembutton'}}
})}}}
$binding | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $bindingPath

$setup=Join-Path $player 'scripts\Setup-BoltgunVR.ps1'
$launcher=Join-Path $player 'scripts\Play-BoltgunVR.ps1'
$setupParams=@{UevrInjectorPath=$fakeInjector;ProfileRoot=$profile;GameConfigRoot=$game;SteamBindingRoot=$steam;SettingsRoot=$settings}
& $setup @setupParams -DryRun -EnableExperimental3D | Out-Null
Assert (-not (Test-Path -LiteralPath $settings)) 'Setup dry run wrote launcher settings.'
Assert (-not (Test-Path -LiteralPath (Join-Path $profile 'scripts'))) 'Setup dry run wrote profile scripts.'

# Unknown files must be preserved and block installation before any writes.
$corrupt=Join-Path $game 'Engine.ini'
$original=[IO.File]::ReadAllBytes($corrupt)
[IO.File]::WriteAllText($corrupt,'unknown external profile')
Expect-Rejection { & $setup @setupParams } 'Unknown original profile hash was accepted.'
Assert (-not (Test-Path -LiteralPath $settings)) 'Failed setup wrote launcher settings.'
Assert (-not (Test-Path -LiteralPath (Join-Path $profile 'scripts'))) 'Failed setup changed original profile.'
[IO.File]::WriteAllBytes($corrupt,$original)

# A conflicting optional plugin must fail the preflight before base files move.
$foreignPlugin=Join-Path $profile 'plugins\boltgun_muzzle.dll'
New-Item -ItemType Directory -Path (Split-Path -Parent $foreignPlugin) -Force | Out-Null
[IO.File]::WriteAllText($foreignPlugin,'external plugin - keep untouched')
Expect-Rejection { & $setup @setupParams -EnableExperimental3D } 'Foreign plugin was accepted.'
Assert (-not (Test-Path -LiteralPath (Join-Path $profile 'scripts'))) 'Optional preflight failed after partial base install.'
Assert ([IO.File]::ReadAllText($foreignPlugin) -eq 'external plugin - keep untouched') 'Optional preflight overwrote a foreign plugin.'
Remove-Item -LiteralPath $foreignPlugin

& $setup @setupParams -EnableExperimental3D | Out-Null
Assert (Test-Path -LiteralPath (Join-Path $profile 'scripts\boltgun_sense.lua')) 'Base profile missing.'
Assert (Test-Path -LiteralPath (Join-Path $profile 'plugins\boltgun_muzzle.dll')) 'Experimental muzzle plugin missing.'
Assert (Test-Path -LiteralPath (Join-Path $profile 'plugins\boltgun_chainsword.dll')) 'Experimental chainsword plugin missing.'
Assert ((Get-Content -LiteralPath (Join-Path $profile 'data\bolter3d.mode') -Raw).Trim() -eq 'preview') '3D arsenal mode incorrect.'
Assert ((Get-Content -LiteralPath (Join-Path $profile 'data\chainsword3d.mode') -Raw).Trim() -eq 'preview') 'Chainsword mode incorrect.'

$saved=Get-Content -LiteralPath (Join-Path $settings 'launcher.json') -Raw | ConvertFrom-Json
Assert ($saved.uevrInjectorPath -eq $fakeInjector) 'Configured injector path incorrect.'
Assert ($saved.steamAppId -eq 2005010 -and $saved.runtime -eq 'OpenXR') 'Wrong game or runtime settings.'
$wouldLaunch=& $launcher -SettingsRoot $settings -DryRun
Assert ([string]::Join(' ',@($wouldLaunch)).Contains('steam://rungameid/2005010')) 'Dry run did not target Boltgun.'

$saved.steamAppId=1
$saved | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $settings 'launcher.json')
Expect-Rejection { & $launcher -SettingsRoot $settings -DryRun } 'Launcher accepted wrong Steam game.'
Write-Output 'Guided setup checks passed: curated ZIP, dry runs, fresh-profile installation, unknown-file refusal, optional modules, saved launcher and game guard.'
Write-Output "Isolated test evidence retained at $sandbox"
