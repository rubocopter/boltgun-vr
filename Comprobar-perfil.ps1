param(
    [string]$ProfileRoot=(Join-Path $env:APPDATA 'UnrealVRMod\Boltgun-Win64-Shipping'),
    [string]$GameConfigRoot=(Join-Path $env:LOCALAPPDATA 'Boltgun\Saved\Config\WindowsNoEditor'),
    [string]$SteamBindingRoot
)
. (Join-Path $PSScriptRoot 'tools\Paths.ps1')
if (-not $SteamBindingRoot) { $SteamBindingRoot = Resolve-BoltgunSteamBindingRoot }
$ErrorActionPreference = 'Stop'
# Read-only checks: never installs, repairs, starts SteamVR or injects UEVR.
$failures = 0
function Check-Result([string]$Label, [bool]$Success) {
    if ($Success) { Write-Output "OK  $Label" }
    else { Write-Output "ERROR  $Label"; $script:failures++ }
}
$entries = Get-BoltgunDeployment -RepositoryRoot $PSScriptRoot -ProfileRoot $ProfileRoot -GameConfigRoot $GameConfigRoot
foreach ($entry in $entries) {
    if ($entry.disabled) { continue }
    $source = Join-Path $PSScriptRoot $entry.source
    $sourceHash = if (Test-Path -LiteralPath $source -PathType Leaf) { (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash } else { '' }
    $targetHash = if (Test-Path -LiteralPath $entry.target -PathType Leaf) { (Get-FileHash -LiteralPath $entry.target -Algorithm SHA256).Hash } else { '' }
    Check-Result "Fuente: $($entry.source)" ($sourceHash -eq $entry.sha256)
    Check-Result "Instalado: $($entry.source)" ($targetHash -eq $entry.sha256)
}
# Optional experiment: check it if installed; its mode/settings are editable
# runtime inputs rather than immutable deployed configuration.
$previewEntry = $entries | Where-Object { $_.disabled -and $_.target.EndsWith('\scripts\boltgun_bolter3d.lua') }
if ($previewEntry -and (Test-Path -LiteralPath $previewEntry.target -PathType Leaf)) {
    $previewSource = Join-Path $PSScriptRoot $previewEntry.source
    Check-Result 'Fuente opcional: bolter 3D' ((Get-FileHash -LiteralPath $previewSource -Algorithm SHA256).Hash -eq $previewEntry.sha256)
    Check-Result 'Instalado opcional: bolter 3D' ((Get-FileHash -LiteralPath $previewEntry.target -Algorithm SHA256).Hash -eq $previewEntry.sha256)
    $previewData = Join-Path (Split-Path -Parent (Split-Path -Parent $previewEntry.target)) 'data'
    $previewModePath = Join-Path $previewData 'bolter3d.mode'
    $previewMode = if (Test-Path -LiteralPath $previewModePath) { [IO.File]::ReadAllText($previewModePath).Trim() } else { 'off' }
    Check-Result "Modo opcional: bolter 3D ($previewMode)" ($previewMode -in @('off','preview'))
    Write-Output 'Bolter 3D: hash/modo comprobados; esta revision del disparo requiere validacion en visor.'
}
$muzzleEntry = $entries | Where-Object { $_.disabled -and $_.target.EndsWith('\plugins\boltgun_muzzle.dll') }
if ($muzzleEntry -and (Test-Path -LiteralPath $muzzleEntry.target -PathType Leaf)) {
    Check-Result 'Fuente opcional: puente de boca de fuego' ((Get-FileHash -LiteralPath (Join-Path $PSScriptRoot $muzzleEntry.source) -Algorithm SHA256).Hash -eq $muzzleEntry.sha256)
    Check-Result 'Instalado opcional: puente de boca de fuego' ((Get-FileHash -LiteralPath $muzzleEntry.target -Algorithm SHA256).Hash -eq $muzzleEntry.sha256)
}
$chainswordPackagePath = Join-Path $PSScriptRoot 'manifests\chainsword3d.package.json'
$chainswordProfile = $ProfileRoot
if (Test-Path -LiteralPath (Join-Path $chainswordProfile 'scripts\boltgun_chainsword.lua')) {
    $chainswordPackage = Get-Content -LiteralPath $chainswordPackagePath -Raw | ConvertFrom-Json
    foreach ($file in $chainswordPackage.files) {
        $source = Join-Path $PSScriptRoot $file.source
        $target = Join-Path $chainswordProfile $file.target
        $sourceHash = if (Test-Path -LiteralPath $source) { (Get-FileHash -LiteralPath $source).Hash } else { '' }
        $targetHash = if (Test-Path -LiteralPath $target) { (Get-FileHash -LiteralPath $target).Hash } else { '' }
        Check-Result "Chainsword fuente: $($file.target)" ($sourceHash -eq $file.sha256)
        Check-Result "Chainsword instalada: $($file.target)" ($targetHash -eq $file.sha256)
    }
    $modePath = Join-Path $chainswordProfile 'data\chainsword3d.mode'
    $chainMode = if (Test-Path -LiteralPath $modePath) { [IO.File]::ReadAllText($modePath).Trim() } else { 'off' }
    Check-Result "Chainsword modo: $chainMode" ($chainMode -in @('off','preview'))
    Write-Output 'Chainsword: integridad comprobada; aparicion, agarre y estabilidad requieren prueba en visor.'
}
$bindingFiles = @(Get-ChildItem -LiteralPath $SteamBindingRoot -Filter 'steam.app.2005010_oculus_touch_*_binding.json' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime, Name -Descending | Select-Object -First 1)
Check-Result 'Binding SteamVR de Boltgun disponible' ($bindingFiles.Count -gt 0)
foreach ($file in $bindingFiles) {
    try {
        $binding = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
        $sources = @($binding.bindings.'/actions/defaultopenxr'.sources)
        $options = @($sources | Where-Object { $_.path -eq '/user/hand/left/input/application_menu' -and $_.inputs.click.output -eq '/actions/defaultopenxr/in/systembutton' })
        $create = @($sources | Where-Object { $_.path -eq '/user/hand/left/input/create' -and $_.inputs.click.output -eq '/actions/defaultopenxr/in/thumbresttouchleft' })
        Check-Result "Options: $($file.Name)" ($options.Count -eq 1)
        Check-Result "Create: $($file.Name)" ($create.Count -eq 1)
    } catch { Check-Result "JSON legible: $($file.Name)" $false }
}
Check-Result 'Sin puente de pausa antiguo en ejecucion' (-not [bool](Get-Process -Name BoltgunPauseBridge -ErrorAction SilentlyContinue))
Write-Output 'Se comprueba el binding mas reciente, con el mismo criterio del instalador; SteamVR puede conservar otros antiguos.'
Write-Output 'Estas comprobaciones no verifican respuesta de botones, mira, manos ni estabilidad en el visor.'
if ($failures -gt 0) { Write-Output "Comprobaciones fallidas: $failures"; exit 1 }
Write-Output 'Comprobaciones locales correctas.'
