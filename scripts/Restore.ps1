param(
    [string]$ProfileRoot=(Join-Path $env:APPDATA 'UnrealVRMod\Boltgun-Win64-Shipping'),
    [string]$GameConfigRoot=(Join-Path $env:LOCALAPPDATA 'Boltgun\Saved\Config\WindowsNoEditor'),
    [string]$SteamBindingRoot,
    [string]$BackupRoot
)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
. (Join-Path $repo 'tools\Paths.ps1')
. (Join-Path $repo 'tools\Snapshots.ps1')
if (Get-Process -Name 'Boltgun-Win64-Shipping' -ErrorAction SilentlyContinue) {
    throw 'Close Boltgun before restoring its configuration.'
}
$entries=@(Get-BoltgunDeployment -RepositoryRoot $repo -ProfileRoot $ProfileRoot -GameConfigRoot $GameConfigRoot)
$snapshot=Get-BoltgunSnapshotPath -RepositoryRoot $repo -ProfileRoot $ProfileRoot -GameConfigRoot $GameConfigRoot -BackupRoot $BackupRoot
$manifest=Assert-BoltgunSnapshot -SnapshotPath $snapshot -ProfileRoot $ProfileRoot -GameConfigRoot $GameConfigRoot
$active=@($entries | Where-Object { -not $_.disabled })
$snapshotEntries=if ($manifest.version -eq 2) { @($entries) } elseif ($manifest.version -eq 1) { $active } else { throw 'Unknown snapshot version.' }
if (@($manifest.entries).Count -ne $snapshotEntries.Count) { throw 'Snapshot inventory differs from this package.' }
$recordsByTarget=@{}
foreach ($record in $manifest.entries) {
    if (-not $record.target -or $recordsByTarget.ContainsKey($record.target)) {
        throw 'Duplicate or missing snapshot destination.'
    }
    $recordsByTarget[$record.target]=$record
}
foreach ($entry in $snapshotEntries) {
    $record=$recordsByTarget[$entry.target]
    if ($record.target -ne $entry.target -or $record.source -ne $entry.source) {
        throw 'Snapshot entry does not match the destination manifest.'
    }
}

# Validate the full restoration before changing any destination. Only files
# with recognised bytes can be replaced or removed.
foreach ($entry in $active) {
    $record=$recordsByTarget[$entry.target]
    if (Test-Path -LiteralPath $entry.target -PathType Leaf) {
        $hash=(Get-FileHash -LiteralPath $entry.target -Algorithm SHA256).Hash
        if ($hash -notin (@($entry.sha256,$entry.originalSha256,$entry.acceptedBaseSha256,$record.sha256) + @($entry.upgradeFrom))) {
            throw "Unknown changes preserved; cannot restore: $($entry.target)"
        }
    }
}
foreach ($entry in $active) {
    $record=$recordsByTarget[$entry.target]
    if ($record.existed) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $entry.target) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $snapshot $record.file) -Destination $entry.target -Force
        if ((Get-FileHash -LiteralPath $entry.target -Algorithm SHA256).Hash -ne $record.sha256) {
            throw "Restored bytes do not match snapshot: $($entry.target)"
        }
    } elseif (Test-Path -LiteralPath $entry.target -PathType Leaf) {
        Remove-Item -LiteralPath $entry.target -Force
    }
}
if ($manifest.version -eq 2) {
    foreach ($entry in @($entries | Where-Object { $_.disabled })) {
        $record=$recordsByTarget[$entry.target]
        $present=Test-Path -LiteralPath $entry.target -PathType Leaf
        $hash=if ($present) { (Get-FileHash -LiteralPath $entry.target -Algorithm SHA256).Hash } else { $null }
        if ($present -and $hash -notin @($entry.sha256,$record.sha256)) {
            Write-Warning "Optional file modified by the user; keeping: $($entry.target)"
            continue
        }
        if ($record.existed) {
            New-Item -ItemType Directory -Path (Split-Path -Parent $entry.target) -Force | Out-Null
            Copy-Item -LiteralPath (Join-Path $snapshot $record.file) -Destination $entry.target -Force
            if ((Get-FileHash -LiteralPath $entry.target -Algorithm SHA256).Hash -ne $record.sha256) {
                throw "Restored optional bytes differ from snapshot: $($entry.target)"
            }
        } elseif ($present) {
            Remove-Item -LiteralPath $entry.target -Force
        }
    }
} else {
    Write-Warning 'Legacy snapshot has no optional-file inventory; optional files were preserved.'
}
Write-Output "Restored pre-install files from $snapshot. User-modified optional files are preserved."
Write-Output 'SteamVR bindings have their own backups under backups/steamvr-runtime.'
