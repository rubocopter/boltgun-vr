param(
    [ValidateSet('install','off','status')][string]$Mode='status',
    [string]$ProfileRoot=(Join-Path $env:APPDATA 'UnrealVRMod\Boltgun-Win64-Shipping'),
    [switch]$DryRun
)
$ErrorActionPreference='Stop'
$taskRoot=$PSScriptRoot
$package=Get-Content -LiteralPath (Join-Path $taskRoot 'manifests\chainsword3d.package.json') -Raw | ConvertFrom-Json
$settingsSource=Join-Path $taskRoot $package.settingsSource
if((Get-FileHash -LiteralPath $settingsSource -Algorithm SHA256).Hash -ne $package.settingsSha256){
    throw 'Los ajustes predeterminados de la espada han cambiado; no se instala sin verificar.'
}
$taskProfile=[IO.Path]::GetFullPath($ProfileRoot).TrimEnd('\')+'\'
$taskMode=Join-Path $taskProfile 'data\chainsword3d.mode'
$taskSettings=Join-Path $taskProfile 'data\chainsword3d.settings'
$currentMode=if(Test-Path -LiteralPath $taskMode){[IO.File]::ReadAllText($taskMode).Trim()}else{'off'}
$pending=@()
foreach($item in $package.files){
    $source=[IO.Path]::GetFullPath((Join-Path $taskRoot $item.source))
    $target=[IO.Path]::GetFullPath((Join-Path $taskProfile $item.target))
    if(!$target.StartsWith($taskProfile,[StringComparison]::OrdinalIgnoreCase)){throw 'Destino fuera del perfil.'}
    $sourceHash=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
    if($sourceHash -ne $item.sha256){throw "Fuente modificada: $source"}
    $targetHash=if(Test-Path -LiteralPath $target){(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash}else{''}
    if($Mode -eq 'status'){
        Write-Output "$($item.target): $(if($targetHash -eq $item.sha256){'OK'}else{'sin instalar o distinto'})"
    }elseif($Mode -eq 'install' -and $targetHash -ne $item.sha256){
        if($targetHash -ne '' -and @($item.upgradeFrom) -notcontains $targetHash){throw "Archivo distinto conservado: $target"}
        $pending+=@{source=$source;target=$target;hash=$sourceHash}
    }
}
if($Mode -eq 'status'){
    Write-Output "Chainsword 3D: $currentMode. Aparicion, escala y orientacion pendientes de visor."
    return
}
if($Mode -eq 'install' -and (Get-Process -Name 'Boltgun-Win64-Shipping' -ErrorAction SilentlyContinue)){
    throw 'Cierra Boltgun para instalar la sierra. No se inicia ni se inyecta desde este helper.'
}
if($DryRun){Write-Output "Simulacion: $($pending.Count) archivos; modo $currentMode -> $Mode. Sin escrituras.";return}
$backup=Join-Path $taskRoot ('backups\chainsword3d\'+(Get-Date -Format 'yyyyMMdd-HHmmss-ffff'))
foreach($path in @($taskMode,$taskSettings)+@($pending | ForEach-Object {$_.target})){
    if(Test-Path -LiteralPath $path -PathType Leaf){
        $relative=$path.Substring($taskProfile.Length)
        $save=Join-Path $backup $relative
        New-Item -ItemType Directory -Path (Split-Path -Parent $save) -Force | Out-Null
        Copy-Item -LiteralPath $path -Destination $save
    }
}
foreach($file in $pending){
    New-Item -ItemType Directory -Path (Split-Path -Parent $file.target) -Force | Out-Null
    Copy-Item -LiteralPath $file.source -Destination $file.target
    if((Get-FileHash -LiteralPath $file.target -Algorithm SHA256).Hash -ne $file.hash){throw 'No coincide el archivo instalado.'}
}
New-Item -ItemType Directory -Path (Join-Path $taskProfile 'data') -Force | Out-Null
if(!(Test-Path -LiteralPath $taskSettings)){
    Copy-Item -LiteralPath $settingsSource -Destination $taskSettings
}
[IO.File]::WriteAllText($taskMode,($(if($Mode -eq 'install'){'preview'}else{'off'}))+[Environment]::NewLine,[Text.UTF8Encoding]::new($false))
Write-Output $(if($Mode -eq 'install'){'Chainsword preparada para la siguiente inyeccion normal de UEVR; sin lanzar SteamVR.'}else{'Chainsword desactivada; su script retira el modelo y restaura el sprite en el siguiente tick.'})
