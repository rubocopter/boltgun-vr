param(
    [ValidateSet('preview','off','status')][string]$Mode='status',
    [string]$ProfileRoot=(Join-Path $env:APPDATA 'UnrealVRMod\Boltgun-Win64-Shipping'),
    [switch]$DryRun
)
$ErrorActionPreference='Stop'
$taskRoot=$PSScriptRoot
$profileRoot=[IO.Path]::GetFullPath($ProfileRoot)
$package=Get-Content -LiteralPath (Join-Path $taskRoot 'manifests\bolter3d.package.json') -Raw | ConvertFrom-Json
$source=[IO.Path]::GetFullPath((Join-Path $taskRoot $package.source))
$sourceHash=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
if($sourceHash -ne $package.sha256){throw 'El prototipo preparado ha cambiado; no se instala sin verificar.'}
$scriptPath=Join-Path $profileRoot 'scripts\boltgun_bolter3d.lua'
$pluginPath=Join-Path $profileRoot 'plugins\boltgun_muzzle.dll'
$pluginSource=if($package.pluginSource){Join-Path $taskRoot $package.pluginSource}else{''}
$pluginHash=if($pluginSource){(Get-FileHash -LiteralPath $pluginSource -Algorithm SHA256).Hash}else{''}
if($pluginHash -and $pluginHash -ne $package.pluginSha256){throw 'El puente nativo ha cambiado; no se instala sin verificar.'}
$installedPluginHash=if(Test-Path -LiteralPath $pluginPath -PathType Leaf){(Get-FileHash -LiteralPath $pluginPath -Algorithm SHA256).Hash}else{''}
$knownPluginHashes=@($package.pluginUpgradeFrom | Where-Object {$_})
$needsPlugin=$Mode -eq 'preview' -and $pluginHash -ne '' -and $installedPluginHash -ne $pluginHash
if($needsPlugin -and $installedPluginHash -ne '' -and $knownPluginHashes -notcontains $installedPluginHash){throw 'Existe un puente nativo distinto; se conserva sin sobrescribirlo.'}
$modePath=Join-Path $profileRoot 'data\bolter3d.mode'
$settingsPath=Join-Path $profileRoot 'data\bolter3d.settings'
$settingsSource=Join-Path $taskRoot $package.settingsSource
$settingsSourceHash=(Get-FileHash -LiteralPath $settingsSource -Algorithm SHA256).Hash
if($package.settingsSha256 -and $settingsSourceHash -ne $package.settingsSha256){throw 'Los ajustes preparados han cambiado; se conservan los instalados.'}
$currentSettingsHash=if(Test-Path -LiteralPath $settingsPath -PathType Leaf){(Get-FileHash -LiteralPath $settingsPath -Algorithm SHA256).Hash}else{''}
$needsSettings=$Mode -eq 'preview' -and ($currentSettingsHash -eq '' -or @($package.upgradeSettingsFrom) -contains $currentSettingsHash)
$installedHash=if(Test-Path -LiteralPath $scriptPath -PathType Leaf){(Get-FileHash -LiteralPath $scriptPath -Algorithm SHA256).Hash}else{''}
$knownPreviousHashes=@($package.upgradeFrom | Where-Object {$_})
$isKnownPrevious=$installedHash -ne '' -and $knownPreviousHashes -contains $installedHash
$currentMode=if(Test-Path -LiteralPath $modePath -PathType Leaf){[IO.File]::ReadAllText($modePath).Trim()}else{'off'}

if($Mode -eq 'status'){
    Write-Output "Arsenal 3D (10 armas): modo $currentMode"
    if($installedHash -eq $sourceHash){Write-Output 'Script experimental instalado y hash correcto.'}
    elseif($isKnownPrevious){Write-Output 'Hay una version anterior reconocida del script; se puede actualizar con copia de seguridad.'}
    elseif($installedHash -eq ''){Write-Output 'Script experimental sin instalar.'}
    else{Write-Output 'El script instalado tiene cambios: se conserva.'}
    Write-Output "Configuracion: $settingsPath"
    if($pluginHash -and $installedPluginHash -eq $pluginHash){Write-Output 'Puente nativo de boca de fuego instalado y hash correcto.'}
    elseif($pluginHash){Write-Output 'Puente nativo pendiente de instalar/actualizar.'}
    Write-Output 'Este estado no comprueba que el modelo aparezca ni su alineacion en el visor.'
    return
}

if($Mode -eq 'preview' -and $installedHash -ne '' -and $installedHash -ne $sourceHash -and -not $isKnownPrevious){
    throw 'Ya existe un script experimental distinto. Se conserva sin sobrescribirlo.'
}
$needsScript=$Mode -eq 'preview' -and $installedHash -ne $sourceHash
if(($needsScript -or $needsPlugin) -and (Get-Process -Name 'Boltgun-Win64-Shipping' -ErrorAction SilentlyContinue)){
    throw 'Cierra Boltgun para instalar por primera vez el prototipo. No se reinicia ni se inyecta desde este helper.'
}
if($DryRun){
    Write-Output "Simulacion: modo $currentMode -> $Mode; instalar script: $needsScript; instalar puente nativo: $needsPlugin; migrar ajustes originales: $needsSettings"
    Write-Output "Destino del script: $scriptPath"
    Write-Output 'Sin escrituras, sin iniciar juegos, SteamVR ni UEVR.'
    return
}

# Preserve existing files before any change. These paths are all exact files;
# this helper never removes files or recursively moves directories.
$backupDir=Join-Path $taskRoot ('backups\bolter3d\'+(Get-Date -Format 'yyyyMMdd-HHmmss-ffff'))
$existing=@($modePath,$settingsPath)
if($needsScript){$existing+=@($scriptPath)}
if($needsPlugin){$existing+=@($pluginPath)}
$existing=@($existing | Where-Object {Test-Path -LiteralPath $_ -PathType Leaf})
if($existing.Count -gt 0){
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    foreach($path in $existing){Copy-Item -LiteralPath $path -Destination (Join-Path $backupDir ([IO.Path]::GetFileName($path)))}
}
New-Item -ItemType Directory -Path (Join-Path $profileRoot 'data') -Force | Out-Null
if($needsScript){
    New-Item -ItemType Directory -Path (Join-Path $profileRoot 'scripts') -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $scriptPath
    if((Get-FileHash -LiteralPath $scriptPath -Algorithm SHA256).Hash -ne $sourceHash){throw 'No coincide el prototipo instalado.'}
}
if($needsPlugin){
    New-Item -ItemType Directory -Path (Join-Path $profileRoot 'plugins') -Force | Out-Null
    Copy-Item -LiteralPath $pluginSource -Destination $pluginPath
    if((Get-FileHash -LiteralPath $pluginPath -Algorithm SHA256).Hash -ne $pluginHash){throw 'No coincide el puente nativo instalado.'}
}
if($needsSettings){
    Copy-Item -LiteralPath $settingsSource -Destination $settingsPath
    if((Get-FileHash -LiteralPath $settingsPath -Algorithm SHA256).Hash -ne $settingsSourceHash){throw 'No coinciden los ajustes instalados.'}
}
$tempPath=$modePath+'.boltgun.tmp'
if(Test-Path -LiteralPath $tempPath){throw 'Existe un archivo temporal previo del selector; se conserva.'}
[IO.File]::WriteAllText($tempPath,$Mode+[Environment]::NewLine,[Text.UTF8Encoding]::new($false))
Move-Item -LiteralPath $tempPath -Destination $modePath -Force
if([IO.File]::ReadAllText($modePath).Trim() -ne $Mode){throw 'No coincide el modo escrito.'}
if($Mode -eq 'preview'){
    Write-Output 'Arsenal 3D del Boltgun original preparado para la siguiente inyeccion normal.'
    Write-Output 'Para cada una de las 10 armas de fuego equipadas, carga su malla y oculta su sprite solo al verificar el componente.'
    Write-Output 'Puente de origen para las 10 armas, con coordenadas independientes compartidas por proyectiles y fogonazos compatibles. Alineacion pendiente de visor.'
}else{
    Write-Output 'Arsenal 3D desactivado. El script queda inerte y conserva los ajustes de calibracion.'
    Write-Output 'Si ya esta cargado, retira su componente en el siguiente tick del motor; cerrar el juego termina esa sesion.'
}
