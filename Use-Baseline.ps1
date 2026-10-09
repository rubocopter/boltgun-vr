param(
    [string]$ProfileRoot=(Join-Path $env:APPDATA 'UnrealVRMod\Boltgun-Win64-Shipping'),
    [string]$GameConfigRoot=(Join-Path $env:LOCALAPPDATA 'Boltgun\Saved\Config\WindowsNoEditor'),
    [string]$SteamBindingRoot
)
. (Join-Path $PSScriptRoot 'tools\Paths.ps1')
if (-not $SteamBindingRoot) { $SteamBindingRoot = Resolve-BoltgunSteamBindingRoot }
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'Restore.ps1') -ProfileRoot $ProfileRoot -GameConfigRoot $GameConfigRoot -SteamBindingRoot $SteamBindingRoot
$taskProfile=Join-Path $ProfileRoot 'config.txt'
$taskText=[IO.File]::ReadAllText($taskProfile)
$taskText=$taskText.Replace('VR_UseFMallocSceneViewExtensions=false','VR_UseFMallocSceneViewExtensions=true')
[IO.File]::WriteAllText($taskProfile,$taskText)
Write-Output 'Perfil original con FMalloc activado. Reinstalar mejoras.cmd recupera v6.'
