$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

function Pause-ForMenu {
    [void](Read-Host 'Press Enter to return to the main menu')
}

function Invoke-MenuAction([scriptblock]$Action) {
    try {
        & $Action
    } catch {
        Write-Host "Action failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    Pause-ForMenu
}

function Set-OptionalModule([string]$ModuleName, [string]$ScriptName, [string]$EnableMode) {
    Clear-Host
    Write-Host "Optional module: $ModuleName"
    Write-Host '1. Enable / install'
    Write-Host '2. Disable'
    Write-Host '0. Back'
    $choice = Read-Host 'Select an option'
    if ($choice -eq '0') { return }
    $mode = switch ($choice) {
        '1' { $EnableMode }
        '2' { 'off' }
        default { Write-Host 'Invalid choice.'; return }
    }
    Invoke-MenuAction { & (Join-Path $PSScriptRoot $ScriptName) -Mode $mode }
}

function Set-TurnMode {
    Clear-Host
    Write-Host 'Turning mode'
    Write-Host '1. Snap turn 30 degrees'
    Write-Host '2. Snap turn 45 degrees'
    Write-Host '3. Snap turn 60 degrees'
    Write-Host '4. Smooth turn'
    Write-Host '0. Back'
    $choice = Read-Host 'Select an option'
    $mode = switch ($choice) {
        '1' { 'Snap30' }
        '2' { 'Snap45' }
        '3' { 'Snap60' }
        '4' { 'Smooth' }
        '0' { return }
        default { Write-Host 'Invalid choice.'; Pause-ForMenu; return }
    }
    Invoke-MenuAction { & (Join-Path $PSScriptRoot 'Elegir-giro.ps1') -Mode $mode }
}

function Install-Profile {
    Clear-Host
    Write-Host 'Install or update Boltgun VR'
    Write-Host '1. Base profile only'
    Write-Host '2. Base profile plus experimental 3D weapons and chainsword'
    Write-Host '0. Back'
    $choice = Read-Host 'Select an option'
    switch ($choice) {
        '1' { Invoke-MenuAction { & (Join-Path $PSScriptRoot 'Setup-BoltgunVR.ps1') } }
        '2' { Invoke-MenuAction { & (Join-Path $PSScriptRoot 'Setup-BoltgunVR.ps1') -EnableExperimental3D } }
        '0' { return }
        default { Write-Host 'Invalid choice.'; Pause-ForMenu }
    }
}

function Show-ProfileStatus {
    Clear-Host
    Write-Host 'Profile and optional module status'
    $checkScript = Join-Path $PSScriptRoot 'Comprobar-perfil.ps1'
    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $checkScript
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Profile check reported issues (exit code $LASTEXITCODE)." -ForegroundColor Yellow
    }
    & (Join-Path $PSScriptRoot 'Bolter3D.ps1') -Mode status
    & (Join-Path $PSScriptRoot 'Chainsword3D.ps1') -Mode status
    Pause-ForMenu
}

function Restore-Profile {
    Clear-Host
    Write-Host 'Restore the profile files from the saved pre-install snapshot.'
    Write-Host 'Boltgun must be closed. User-edited files are protected.'
    $confirmation = Read-Host 'Type RESTORE to continue, or press Enter to cancel'
    if ($confirmation -cne 'RESTORE') { return }
    Invoke-MenuAction { & (Join-Path $PSScriptRoot 'Restore.ps1') }
}

while ($true) {
    Clear-Host
    Write-Host '=========================================='
    Write-Host '              BOLTGUN VR'
    Write-Host '=========================================='
    Write-Host '1. Install or update the VR profile'
    Write-Host '2. Start Boltgun and open the UEVR frontend'
    Write-Host '3. Enable or disable the 3D firearm arsenal'
    Write-Host '4. Enable or disable the 3D chainsword'
    Write-Host '5. Change turning mode'
    Write-Host '6. Check profile and module status'
    Write-Host '7. Restore the previous profile'
    Write-Host '8. Open the README'
    Write-Host '0. Exit'
    $choice = Read-Host 'Select an option'

    switch ($choice) {
        '1' { Install-Profile }
        '2' { Invoke-MenuAction { & (Join-Path $PSScriptRoot 'Play-BoltgunVR.ps1') } }
        '3' { Set-OptionalModule '3D firearm arsenal' 'Bolter3D.ps1' 'preview' }
        '4' { Set-OptionalModule '3D chainsword' 'Chainsword3D.ps1' 'install' }
        '5' { Set-TurnMode }
        '6' { Show-ProfileStatus }
        '7' { Restore-Profile }
        '8' { Start-Process -FilePath (Join-Path $repoRoot 'README.md') }
        '0' { break }
        default { Write-Host 'Invalid choice.'; Pause-ForMenu }
    }
    if ($choice -eq '0') { break }
}
