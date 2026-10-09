param(
    [string]$ProfileRoot=(Join-Path $env:APPDATA 'UnrealVRMod\Boltgun-Win64-Shipping'),
    [string]$GameConfigRoot=(Join-Path $env:LOCALAPPDATA 'Boltgun\Saved\Config\WindowsNoEditor'),
    [string]$SteamBindingRoot
)
. (Join-Path $PSScriptRoot 'tools\Paths.ps1')
if (-not $SteamBindingRoot) { $SteamBindingRoot = Resolve-BoltgunSteamBindingRoot }
$ErrorActionPreference = 'Stop'
$taskRoot = $PSScriptRoot
if (Get-Process -Name 'Boltgun-Win64-Shipping' -ErrorAction SilentlyContinue) {
    throw 'Cierra Boltgun antes de aplicar el perfil.'
}

function Patch-BoltgunSteamVrBinding {
    $bindingDir = $SteamBindingRoot
    $bindingFile = Get-ChildItem -LiteralPath $bindingDir -Filter 'steam.app.2005010_oculus_touch_*_binding.json' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime, Name -Descending |
        Select-Object -First 1
    if (-not $bindingFile) {
        Write-Warning 'SteamVR aun no ha generado el binding Oculus de Boltgun. Inyecta UEVR una vez y vuelve a ejecutar Reinstalar mejoras.cmd.'
        return
    }

    $binding = Get-Content -LiteralPath $bindingFile.FullName -Raw | ConvertFrom-Json
    $actionSet = $binding.bindings.'/actions/defaultopenxr'
    if (-not $actionSet -or -not $actionSet.sources) {
        throw "Binding de SteamVR inesperado: $($bindingFile.FullName)"
    }

    $sources = @($actionSet.sources)
    $systemButton = @($sources | Where-Object { $_.inputs.click.output -eq '/actions/defaultopenxr/in/systembutton' })
    if ($systemButton.Count -ne 1) {
        throw "No se encontro un unico SystemButton en $($bindingFile.FullName)"
    }

    $changed = $false
    if ($systemButton[0].path -eq '/user/hand/left/input/menu') {
        $systemButton[0].path = '/user/hand/left/input/application_menu'
        $changed = $true
    } elseif ($systemButton[0].path -ne '/user/hand/left/input/application_menu') {
        throw "SystemButton usa una ruta no reconocida: $($systemButton[0].path)"
    }

    $createOutput = '/actions/defaultopenxr/in/thumbresttouchleft'
    $createPath = '/user/hand/left/input/create'
    $createBinding = @($sources | Where-Object { $_.path -eq $createPath -and $_.inputs.click.output -eq $createOutput })
    if ($createBinding.Count -eq 0) {
        $collision = @($sources | Where-Object { $_.inputs.click.output -eq $createOutput -or $_.inputs.touch.output -eq $createOutput })
        if ($collision.Count -gt 0) {
            throw 'ThumbrestTouchLeft ya esta ocupado en el binding activo; no se modifica para evitar recenter accidentales.'
        }
        $newSource = [pscustomobject]@{
            inputs = [pscustomobject]@{
                click = [pscustomobject]@{ output = $createOutput }
            }
            mode = 'button'
            parameters = [pscustomobject]@{
                force_input = 'click'
                haptic_amplitude = 0
            }
            path = $createPath
        }
        $actionSet.sources = @($sources + $newSource)
        $changed = $true
    }

    if ($changed) {
        $beforeHash = (Get-FileHash -LiteralPath $bindingFile.FullName -Algorithm SHA256).Hash
        $backupDir = Join-Path $taskRoot 'backups\steamvr-runtime'
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        $backupPath = Join-Path $backupDir ($bindingFile.BaseName + '.before-sense-v6.' + $beforeHash.Substring(0, 12) + '.json')
        if (-not (Test-Path -LiteralPath $backupPath)) {
            Copy-Item -LiteralPath $bindingFile.FullName -Destination $backupPath
        }

        $tempPath = $bindingFile.FullName + '.boltgun-sense.tmp'
        $jsonText = $binding | ConvertTo-Json -Depth 20
        [IO.File]::WriteAllText($tempPath, $jsonText + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
        Get-Content -LiteralPath $tempPath -Raw | ConvertFrom-Json | Out-Null
        Move-Item -LiteralPath $tempPath -Destination $bindingFile.FullName -Force
    }

    $verified = Get-Content -LiteralPath $bindingFile.FullName -Raw | ConvertFrom-Json
    $verifiedSources = @($verified.bindings.'/actions/defaultopenxr'.sources)
    if (-not ($verifiedSources | Where-Object { $_.path -eq '/user/hand/left/input/application_menu' -and $_.inputs.click.output -eq '/actions/defaultopenxr/in/systembutton' })) {
        throw 'No se pudo verificar el binding de Options.'
    }
    if (-not ($verifiedSources | Where-Object { $_.path -eq $createPath -and $_.inputs.click.output -eq $createOutput })) {
        throw 'No se pudo verificar el binding de Create.'
    }
    Write-Output "Binding SteamVR de Boltgun preparado: $($bindingFile.Name)"
}

$taskEntries = Get-BoltgunDeployment -RepositoryRoot $taskRoot -ProfileRoot $ProfileRoot -GameConfigRoot $GameConfigRoot
foreach ($taskEntry in $taskEntries) {
    if ($taskEntry.disabled) { continue }
    $taskSource = Join-Path $taskRoot $taskEntry.source
    if ((Get-FileHash -LiteralPath $taskSource -Algorithm SHA256).Hash -ne $taskEntry.sha256) {
        throw "Archivo preparado modificado: $taskSource"
    }
    if (Test-Path -LiteralPath $taskEntry.target) {
        $taskCurrent = (Get-FileHash -LiteralPath $taskEntry.target -Algorithm SHA256).Hash
        if ($taskCurrent -ne $taskEntry.sha256 -and $taskCurrent -ne $taskEntry.originalSha256 -and $taskCurrent -ne $taskEntry.acceptedBaseSha256) {
            throw "Hay cambios posteriores en $($taskEntry.target). Conservados; revisalos antes de reinstalar."
        }
    } elseif ($taskEntry.originalSha256) {
        throw "Falta el archivo original: $($taskEntry.target)"
    }
}
foreach ($taskEntry in $taskEntries) {
    if ($taskEntry.disabled) { continue }
    New-Item -ItemType Directory -Path (Split-Path -Parent $taskEntry.target) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $taskRoot $taskEntry.source) -Destination $taskEntry.target -Force
    if ((Get-FileHash -LiteralPath $taskEntry.target -Algorithm SHA256).Hash -ne $taskEntry.sha256) {
        throw "No coincide el archivo instalado: $($taskEntry.target)"
    }
}
Patch-BoltgunSteamVrBinding
Write-Output 'Perfil Boltgun Sense v7 instalado. Inicia Boltgun normalmente e inyecta UEVR con OpenXR; no hace falta el BAT de juego ni el puente de pausa.'
