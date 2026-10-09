param(
    [string]$UevrInjectorPath,
    [string]$ProfileRoot=(Join-Path $env:APPDATA 'UnrealVRMod\Boltgun-Win64-Shipping'),
    [string]$GameConfigRoot=(Join-Path $env:LOCALAPPDATA 'Boltgun\Saved\Config\WindowsNoEditor'),
    [string]$SteamBindingRoot,
    [string]$SettingsRoot=(Join-Path $env:LOCALAPPDATA 'BoltgunVR'),
    [switch]$EnableExperimental3D,
    [string]$BackupRoot,
    [switch]$DryRun
)

$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
. (Join-Path $repo 'tools\Paths.ps1')
if (-not $SteamBindingRoot) { $SteamBindingRoot=Resolve-BoltgunSteamBindingRoot }
$officialUevr='https://github.com/praydog/UEVR/releases'

Write-Output 'Boltgun VR - guided setup (OpenXR)'
Write-Output 'UEVR and the original game are separate dependencies; no third-party software is downloaded.'

if (-not $UevrInjectorPath -and -not $DryRun) {
    Write-Output "Get UEVR from the official source: $officialUevr"
    Write-Output 'Choose the UEVRInjector.exe you downloaded and extracted yourself.'
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $picker=New-Object System.Windows.Forms.OpenFileDialog
        $picker.Title='Choose your official UEVRInjector.exe'
        $picker.Filter='UEVR injector (UEVRInjector.exe)|UEVRInjector.exe'
        $picker.CheckFileExists=$true
        if ($picker.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $UevrInjectorPath=$picker.FileName
        }
        $picker.Dispose()
    } catch {
        Write-Warning 'File picker unavailable; enter the location manually.'
    }
    if (-not $UevrInjectorPath) {
        $UevrInjectorPath=Read-Host 'Full path to UEVRInjector.exe (or leave blank to cancel)'
    }
}
if ($UevrInjectorPath) { $UevrInjectorPath=$UevrInjectorPath.Trim().Trim('"') }
if (-not $UevrInjectorPath -or -not (Test-Path -LiteralPath $UevrInjectorPath -PathType Leaf) -or
    [IO.Path]::GetFileName($UevrInjectorPath) -ne 'UEVRInjector.exe') {
    throw "UEVRInjector.exe was not found. Download UEVR yourself from $officialUevr, extract it and provide -UevrInjectorPath. No downloads were attempted."
}
$UevrInjectorPath=[IO.Path]::GetFullPath($UevrInjectorPath)

if (Get-Process -Name 'Boltgun-Win64-Shipping' -ErrorAction SilentlyContinue) {
    throw 'Close Boltgun before installing its VR profile.'
}

# Verify packaged sources and reject foreign changes before writing.
& (Join-Path $repo 'tools\Check-Repository.ps1') | Out-Host
$entries=Get-BoltgunDeployment -RepositoryRoot $repo -ProfileRoot $ProfileRoot -GameConfigRoot $GameConfigRoot
foreach ($entry in $entries) {
    if ($entry.disabled) { continue }
    if (-not (Test-Path -LiteralPath $entry.target -PathType Leaf)) {
        continue
    }
    $hash=(Get-FileHash -LiteralPath $entry.target -Algorithm SHA256).Hash
    if ($hash -notin @($entry.sha256,$entry.originalSha256,$entry.acceptedBaseSha256)) {
        throw "An existing file contains unknown changes and will be preserved: $($entry.target)"
    }
}

$binding=Get-ChildItem -LiteralPath $SteamBindingRoot -Filter 'steam.app.2005010_oculus_touch_*_binding.json' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $binding) {
    Write-Warning 'UEVR/SteamVR must generate the Oculus Touch binding at least once for the PS VR2 Options/Create mappings.'
}

if ($EnableExperimental3D) {
    # Validate optional inputs before the base installer makes any changes.
    & (Join-Path $repo 'scripts\Bolter3D.ps1') -Mode preview -ProfileRoot $ProfileRoot -DryRun
    & (Join-Path $repo 'scripts\Chainsword3D.ps1') -Mode install -ProfileRoot $ProfileRoot -DryRun
}
if ($DryRun) {
    Write-Output 'Preflight OK. No profile, launcher settings, game process, UEVR or SteamVR were changed.'
    return
}

& (Join-Path $repo 'scripts\Install.ps1') -ProfileRoot $ProfileRoot -GameConfigRoot $GameConfigRoot -SteamBindingRoot $SteamBindingRoot -BackupRoot $BackupRoot
if ($EnableExperimental3D) {
    & (Join-Path $repo 'scripts\Bolter3D.ps1') -Mode preview -ProfileRoot $ProfileRoot
    & (Join-Path $repo 'scripts\Chainsword3D.ps1') -Mode install -ProfileRoot $ProfileRoot
}

New-Item -ItemType Directory -Path $SettingsRoot -Force | Out-Null
$config=[ordered]@{
    uevrInjectorPath=$UevrInjectorPath
    runtime='OpenXR'
    steamAppId=2005010
}
$settingsPath=Join-Path $SettingsRoot 'launcher.json'
[IO.File]::WriteAllText($settingsPath, ($config | ConvertTo-Json)+"`n", [Text.UTF8Encoding]::new($false))
Write-Output "Ready: launcher settings stored at $settingsPath"
Write-Output 'Use Jugar Boltgun VR.cmd to open the game and official UEVR frontend.'
Write-Output 'Injection still requires pressing Inject in the official UEVR window.'
