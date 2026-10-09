param(
    [string]$SettingsRoot=(Join-Path $env:LOCALAPPDATA 'BoltgunVR'),
    [switch]$DryRun
)

$ErrorActionPreference='Stop'
$settingsPath=Join-Path $SettingsRoot 'launcher.json'
if (-not (Test-Path -LiteralPath $settingsPath -PathType Leaf)) {
    throw 'Boltgun VR is not configured. Run Instalar Boltgun VR.cmd first.'
}
$settings=Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
if ($settings.steamAppId -ne 2005010 -or $settings.runtime -ne 'OpenXR') {
    throw 'Unknown launcher settings: refusing to start a different game/runtime.'
}
$injector=[string]$settings.uevrInjectorPath
if (-not $injector -or [IO.Path]::GetFileName($injector) -ne 'UEVRInjector.exe' -or
    -not (Test-Path -LiteralPath $injector -PathType Leaf)) {
    throw 'UEVRInjector.exe is missing or moved. Run Instalar Boltgun VR.cmd to select its new location.'
}
if ($DryRun) {
    Write-Output "Would open $injector and steam://rungameid/2005010. No process started."
    return
}

# The official injector has no documented unattended-injection CLI interface.
# Launch the user's own unmodified frontend; they perform injection in its GUI.
Start-Process -FilePath $injector
Start-Process -FilePath 'steam://rungameid/2005010'
Write-Output 'Boltgun and official UEVR frontend opened. Select Boltgun, OpenXR and Inject in UEVR.'
