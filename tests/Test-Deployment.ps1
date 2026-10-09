$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$sandbox = Join-Path $repo ('build\deployment-check-' + [guid]::NewGuid().ToString('N'))
$copy = Join-Path $sandbox 'repository'
$profile = Join-Path $sandbox 'profile'
$game = Join-Path $sandbox 'game-config'
$steam = Join-Path $sandbox 'steam'
New-Item -ItemType Directory -Path $copy,$profile,$game,$steam -Force | Out-Null
# Explicit source inventory: this copy has no research, private backups or Python bundle.
foreach ($directory in @('src','profile','game-config','assets','manifests','dependencies')) {
    Copy-Item -LiteralPath (Join-Path $repo $directory) -Destination $copy -Recurse
}
New-Item -ItemType Directory -Path (Join-Path $copy 'tools') -Force | Out-Null
Copy-Item -Path (Join-Path $repo 'tools\*.ps1') -Destination (Join-Path $copy 'tools')
foreach ($path in Get-ChildItem -LiteralPath $repo -File | Where-Object { $_.Extension -in @('.ps1','.json') }) {
    Copy-Item -LiteralPath $path.FullName -Destination $copy
}
New-Item -ItemType Directory -Path (Join-Path $copy 'build\plugins') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $repo 'build\plugins\boltgun_muzzle.dll') -Destination (Join-Path $copy 'build\plugins')
Copy-Item -LiteralPath (Join-Path $repo 'build\plugins\boltgun_chainsword.dll') -Destination (Join-Path $copy 'build\plugins')
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path).Hash }
function Expect-Rejection([scriptblock]$Action) {
    $rejected = $false
    try { & $Action | Out-Null } catch { $rejected = $true }
    Assert $rejected 'Expected rejection did not happen.'
}
Copy-Item -LiteralPath (Join-Path $copy 'profile\baseline\uevr\config.txt') -Destination $profile
foreach ($name in @('Engine.ini','Input.ini')) {
    Copy-Item -LiteralPath (Join-Path $copy "profile\baseline\game-config\$name") -Destination $game
}
$bindingPath = Join-Path $steam 'steam.app.2005010_oculus_touch_test_binding.json'
$binding = @{ bindings = @{ '/actions/defaultopenxr' = @{ sources = @(@{
    path='/user/hand/left/input/menu'; mode='button';
    inputs=@{click=@{output='/actions/defaultopenxr/in/systembutton'}}
}) } } }
$binding | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $bindingPath
& (Join-Path $copy 'Install.ps1') -ProfileRoot $profile -GameConfigRoot $game -SteamBindingRoot $steam
Assert ((Hash (Join-Path $profile 'config.txt')) -eq (Hash (Join-Path $copy 'profile\config.txt'))) 'Base installation failed.'
& (Join-Path $copy 'Bolter3D.ps1') -Mode preview -ProfileRoot $profile -DryRun
Assert (-not (Test-Path -LiteralPath (Join-Path $profile 'scripts\boltgun_bolter3d.lua'))) 'DryRun wrote a module.'
& (Join-Path $copy 'Bolter3D.ps1') -Mode preview -ProfileRoot $profile
& (Join-Path $copy 'Chainsword3D.ps1') -Mode install -ProfileRoot $profile
& (Join-Path $copy 'Comprobar-perfil.ps1') -ProfileRoot $profile -GameConfigRoot $game -SteamBindingRoot $steam
foreach ($name in @('bolter3d.settings','chainsword3d.settings')) {
    [IO.File]::WriteAllText((Join-Path $profile "data\$name"), 'custom_calibration=123')
}
& (Join-Path $copy 'Bolter3D.ps1') -Mode preview -ProfileRoot $profile
& (Join-Path $copy 'Chainsword3D.ps1') -Mode install -ProfileRoot $profile
foreach ($name in @('bolter3d.settings','chainsword3d.settings')) {
    Assert ([IO.File]::ReadAllText((Join-Path $profile "data\$name")) -eq 'custom_calibration=123') 'Custom calibration overwritten.'
}
$scriptPath = Join-Path $profile 'scripts\boltgun_bolter3d.lua'
$known = [IO.File]::ReadAllBytes($scriptPath)
[IO.File]::WriteAllText($scriptPath, 'unknown replacement')
Expect-Rejection { & (Join-Path $copy 'Bolter3D.ps1') -Mode preview -ProfileRoot $profile }
Assert ([IO.File]::ReadAllText($scriptPath) -eq 'unknown replacement') 'Unknown script overwritten.'
[IO.File]::WriteAllBytes($scriptPath, $known)
& (Join-Path $copy 'Bolter3D.ps1') -Mode off -ProfileRoot $profile
& (Join-Path $copy 'Chainsword3D.ps1') -Mode off -ProfileRoot $profile
Assert ([IO.File]::ReadAllText((Join-Path $profile 'data\bolter3d.mode')).Trim() -eq 'off') 'Arsenal deactivation failed.'
Assert ([IO.File]::ReadAllText((Join-Path $profile 'data\chainsword3d.mode')).Trim() -eq 'off') 'Sword deactivation failed.'
& (Join-Path $copy 'Elegir-giro.ps1') -Mode Snap30 -ProfileRoot $profile -GameConfigRoot $game
Assert ([IO.File]::ReadAllText((Join-Path $profile 'config.txt')).Contains('VR_SnapturnTurnAngle=30')) 'Turn selection failed.'
& (Join-Path $copy 'Restore.ps1') -ProfileRoot $profile -GameConfigRoot $game -SteamBindingRoot $steam
Assert ((Hash (Join-Path $profile 'config.txt')) -eq (Hash (Join-Path $copy 'profile\baseline\uevr\config.txt'))) 'Baseline restoration failed.'
Assert (-not (Test-Path -LiteralPath $scriptPath)) 'Optional module survived baseline restoration.'
# Reject traversal before any installation writes.
$manifestPath = Join-Path $copy 'deployment.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$manifest[0].target = '${ProfileRoot}\..\outside.txt'
$manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $manifestPath
Expect-Rejection { & (Join-Path $copy 'Install.ps1') -ProfileRoot $profile -GameConfigRoot $game -SteamBindingRoot $steam }
Assert (-not (Test-Path -LiteralPath (Join-Path $sandbox 'outside.txt'))) 'Traversal escaped the profile.'
Write-Output 'Deployment checks passed: isolated installation, dry run, calibration, unknown-file refusal, off, turn, baseline and traversal.'
Write-Output "Temporary evidence retained at $sandbox"
