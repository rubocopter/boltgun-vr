param(
    [ValidateSet('Snap30','Snap45','Snap60','Smooth')]
    [string]$Mode,
    [string]$ProfileRoot=(Join-Path $env:APPDATA 'UnrealVRMod\Boltgun-Win64-Shipping'),
    [string]$GameConfigRoot=(Join-Path $env:LOCALAPPDATA 'Boltgun\Saved\Config\WindowsNoEditor')
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'tools\Paths.ps1')
if (Get-Process -Name 'Boltgun-Win64-Shipping' -ErrorAction SilentlyContinue) {
    throw 'Cierra Boltgun antes de cambiar el giro. No se modifica nada.'
}
if (-not $Mode) {
    Write-Host '1: Snap 30 grados'
    Write-Host '2: Snap 45 grados'
    Write-Host '3: Snap 60 grados'
    Write-Host '4: Giro suave (velocidad controlada por el juego)'
    $choice = Read-Host 'Elige 1-4; Enter para cancelar'
    $Mode = switch ($choice) {
        '1' { 'Snap30' }
        '2' { 'Snap45' }
        '3' { 'Snap60' }
        '4' { 'Smooth' }
        default { return }
    }
    if (-not $Mode) { return }
}
$manifestPath = Join-Path $PSScriptRoot 'deployment.json'
$entries = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$entry = $entries | Where-Object source -eq 'profile\config.txt'
$sourcePath = Join-Path $PSScriptRoot $entry.source
$resolvedEntry = Get-BoltgunDeployment -RepositoryRoot $PSScriptRoot -ProfileRoot $ProfileRoot -GameConfigRoot $GameConfigRoot | Where-Object source -eq 'profile\config.txt'
$installedTarget = $resolvedEntry.target
$paths = @($sourcePath, $installedTarget)
$texts = @()
foreach ($path in $paths) {
    $text = [IO.File]::ReadAllText($path)
    foreach ($key in @('VR_SnapTurn','VR_SnapturnTurnAngle')) {
        if ([regex]::Matches($text, "(?m)^$key=.+$").Count -ne 1) {
            throw "Clave ausente o duplicada: $key en $path. No se modifica nada."
        }
    }
    $texts += $text
}
$backupDir = Join-Path $PSScriptRoot ('backups\turn-' + [DateTime]::Now.ToString('yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $backupDir | Out-Null
Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $backupDir 'deployment.json')
Copy-Item -LiteralPath $sourcePath -Destination (Join-Path $backupDir 'source-config.txt')
Copy-Item -LiteralPath $installedTarget -Destination (Join-Path $backupDir 'installed-config.txt')
$previousHash = (Get-FileHash -LiteralPath $installedTarget).Hash
for ($i = 0; $i -lt $paths.Count; $i++) {
    $value = if ($Mode -eq 'Smooth') { 'false' } else { 'true' }
    $updated = [regex]::Replace($texts[$i], '(?m)^VR_SnapTurn=[^\r\n]+', "VR_SnapTurn=$value")
    if ($Mode -ne 'Smooth') {
        $angle = $Mode.Substring(4)
        $updated = [regex]::Replace($updated, '(?m)^VR_SnapturnTurnAngle=[^\r\n]+', "VR_SnapturnTurnAngle=$angle")
    }
    [IO.File]::WriteAllText($paths[$i], $updated, [Text.UTF8Encoding]::new($false))
}
$entry.acceptedBaseSha256 = $previousHash
$entry.sha256 = (Get-FileHash -LiteralPath $sourcePath).Hash
[IO.File]::WriteAllText($manifestPath, ($entries | ConvertTo-Json -Depth 8) + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
Write-Host "Giro guardado: $Mode. Se aplica en la proxima inyeccion."
Write-Host "Copia anterior: $backupDir"
