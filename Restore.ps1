param(
    [string]$ProfileRoot=(Join-Path $env:APPDATA 'UnrealVRMod\Boltgun-Win64-Shipping'),
    [string]$GameConfigRoot=(Join-Path $env:LOCALAPPDATA 'Boltgun\Saved\Config\WindowsNoEditor'),
    [string]$SteamBindingRoot
)
. (Join-Path $PSScriptRoot 'tools\Paths.ps1')
if (-not $SteamBindingRoot) { $SteamBindingRoot = Resolve-BoltgunSteamBindingRoot }
$ErrorActionPreference = 'Stop'
if (Get-Process -Name 'Boltgun-Win64-Shipping' -ErrorAction SilentlyContinue) {
    throw 'Cierra Boltgun antes de restaurar.'
}
$taskEntries = Get-BoltgunDeployment -RepositoryRoot $PSScriptRoot -ProfileRoot $ProfileRoot -GameConfigRoot $GameConfigRoot
$taskAllowedRoots = @(
    ([IO.Path]::GetFullPath($ProfileRoot).TrimEnd('\')+'\'),
    ([IO.Path]::GetFullPath($GameConfigRoot).TrimEnd('\')+'\')
)
foreach ($taskEntry in $taskEntries) {
    $taskResolved = [System.IO.Path]::GetFullPath($taskEntry.target)
    $taskAllowed = $false
    foreach ($taskAllowedRoot in $taskAllowedRoots) {
        if ($taskResolved.StartsWith($taskAllowedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            $taskAllowed = $true
        }
    }
    if (-not $taskAllowed) { throw "Destino fuera del perfil: $taskResolved" }
    if ($taskEntry.backup) {
        $taskBackup = Join-Path $PSScriptRoot $taskEntry.backup
        if ((Get-FileHash -LiteralPath $taskBackup -Algorithm SHA256).Hash -ne $taskEntry.originalSha256) {
            throw "Copia original modificada: $taskBackup"
        }
    }
}
foreach ($taskEntry in $taskEntries) {
    if ($taskEntry.backup) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $taskEntry.backup) -Destination $taskEntry.target -Force
        if ((Get-FileHash -LiteralPath $taskEntry.target -Algorithm SHA256).Hash -ne $taskEntry.originalSha256) {
            throw "No coincide el original restaurado: $($taskEntry.target)"
        }
    } elseif (Test-Path -LiteralPath $taskEntry.target) {
        # Delete only exact files created by this package, never directories.
        Remove-Item -LiteralPath $taskEntry.target -Force
    }
}
Write-Output 'Restaurados los archivos originales. Las partidas guardadas no se han modificado.'
