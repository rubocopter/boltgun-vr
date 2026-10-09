param(
    [string]$ProfileRoot=(Join-Path $env:APPDATA 'UnrealVRMod\Boltgun-Win64-Shipping'),
    [string]$GameConfigRoot=(Join-Path $env:LOCALAPPDATA 'Boltgun\Saved\Config\WindowsNoEditor'),
    [string]$SteamBindingRoot,
    [string]$SettingsRoot=(Join-Path $env:LOCALAPPDATA 'BoltgunVR'),
    [string]$OutputRoot=(Join-Path (Split-Path -Parent $PSScriptRoot) 'backups\reinstall'),
    [string]$SnapshotName=(Get-Date -Format 'yyyyMMdd-HHmmss')
)

$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Paths.ps1')
if (-not $SteamBindingRoot) { $SteamBindingRoot=Resolve-BoltgunSteamBindingRoot }
if ($SnapshotName -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*$' -or $SnapshotName -in @('.','..')) {
    throw 'SnapshotName must be a single safe folder name.'
}
if (Get-Process -Name 'Boltgun-Win64-Shipping' -ErrorAction SilentlyContinue) {
    throw 'Close Boltgun before capturing a consistent backup.'
}
foreach ($root in @($ProfileRoot,$GameConfigRoot)) {
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw "Source folder missing: $root" }
}

$snapshot=Join-Path $OutputRoot $SnapshotName
if (Test-Path -LiteralPath $snapshot) { throw "Snapshot exists; refusing to overwrite: $snapshot" }
New-Item -ItemType Directory -Path $snapshot -Force | Out-Null
$script:snapshotFiles=[Collections.Generic.List[object]]::new()

function Save-File([string]$Area, [string]$Root, [string]$Relative) {
    $original=Join-Path $Root $Relative
    $target=Join-Path (Join-Path $snapshot $Area) $Relative
    $parent=Split-Path -Parent $target
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    $hashBefore=(Get-FileHash -LiteralPath $original -Algorithm SHA256).Hash
    Copy-Item -LiteralPath $original -Destination $target -ErrorAction Stop
    $hashAfter=(Get-FileHash -LiteralPath $original -Algorithm SHA256).Hash
    $copiedHash=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
    if ($hashBefore -ne $hashAfter -or $copiedHash -ne $hashBefore) {
        throw "File changed during backup or copy failed: $original"
    }
    $script:snapshotFiles.Add([ordered]@{
        area=$Area
        relativePath=$Relative
        sha256=$copiedHash
        bytes=(Get-Item -LiteralPath $target).Length
    })
}

$uevrRootFiles=@('config.txt','actions.json','cameras.txt','imgui.ini','_interaction_profiles_oculus_touch_controller.json')
foreach ($file in Get-ChildItem -LiteralPath $ProfileRoot -File) {
    if ($file.Name -in $uevrRootFiles -or $file.Name -match '^bindings?_[A-Za-z0-9_-]+\.json$') {
        Save-File 'uevr-profile' $ProfileRoot $file.Name
    }
}
foreach ($subdir in @('data','scripts','plugins','uobjecthook')) {
    $folder=Join-Path $ProfileRoot $subdir
    if (-not (Test-Path -LiteralPath $folder -PathType Container)) { continue }
    foreach ($file in Get-ChildItem -LiteralPath $folder -File -Recurse) {
        if ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
        $relative=$file.FullName.Substring($ProfileRoot.TrimEnd('\').Length+1)
        if ($relative -match '(?i)\.(dmp|log|exe|pak|mp4|avi|pdb)$') { continue }
        if ($relative -match '(?i)^data[\\/]((pause\.(request|status))|(wheel\.recovery))$') { continue }
        if ($subdir -eq 'plugins' -and $file.Name -notmatch '^boltgun_[\w-]+\.dll$') { continue }
        if ($file.Extension -notin @('.json','.ini','.txt','.lua','.dll','.mode','.settings','.owned','.texture_path','.bgmesh','.png','.disabled')) { continue }
        Save-File 'uevr-profile' $ProfileRoot $relative
    }
}
foreach ($file in Get-ChildItem -LiteralPath $GameConfigRoot -File -Filter '*.ini') {
    Save-File 'game-config' $GameConfigRoot $file.Name
}
if (Test-Path -LiteralPath $SteamBindingRoot -PathType Container) {
    foreach ($file in Get-ChildItem -LiteralPath $SteamBindingRoot -File -Filter 'steam.app.2005010_*_binding.json') {
        Save-File 'steam-bindings' $SteamBindingRoot $file.Name
    }
}
$launcherPath=Join-Path $SettingsRoot 'launcher.json'
if (Test-Path -LiteralPath $launcherPath -PathType Leaf) {
    Save-File 'launcher-settings' $SettingsRoot 'launcher.json'
}

$manifest=[ordered]@{
    version=1
    createdUtc=[DateTime]::UtcNow.ToString('o')
    sourceRoots=[ordered]@{
        'uevr-profile'=$ProfileRoot
        'game-config'=$GameConfigRoot
        'steam-bindings'=$SteamBindingRoot
        'launcher-settings'=$SettingsRoot
    }
    files=@($script:snapshotFiles.ToArray())
}
$json=$manifest | ConvertTo-Json -Depth 6
[IO.File]::WriteAllText((Join-Path $snapshot 'manifest.json'), $json+"`n", [Text.UTF8Encoding]::new($false))
Write-Output "Private reinstall backup: $snapshot"
Write-Output "Files captured and SHA-256 verified: $($script:snapshotFiles.Count)"
if (-not ($script:snapshotFiles | Where-Object { $_.area -eq 'steam-bindings' })) {
    Write-Warning 'No Boltgun SteamVR bindings found; generate them with the headset after reinstalling.'
}
Write-Output 'The default backups/ location is Git-ignored; keep the snapshot on your retained drive.'
