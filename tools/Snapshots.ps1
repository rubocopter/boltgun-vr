# Private, byte-preserving snapshots of declared deployment destinations.
# A snapshot is keyed by the two destination roots, so reinstalling the same
# profile never replaces the user's pre-install copies with modded files.
function Get-BoltgunSnapshotPath {
    param([string]$RepositoryRoot,[string]$ProfileRoot,[string]$GameConfigRoot,[string]$BackupRoot)
    if (-not $BackupRoot) { $BackupRoot=Join-Path $RepositoryRoot 'backups\install' }
    $identity=([IO.Path]::GetFullPath($ProfileRoot).TrimEnd('\')+'|'+[IO.Path]::GetFullPath($GameConfigRoot).TrimEnd('\')).ToLowerInvariant()
    $hasher=[Security.Cryptography.SHA256]::Create()
    try { $sha=$hasher.ComputeHash([Text.Encoding]::UTF8.GetBytes($identity)) }
    finally { $hasher.Dispose() }
    $key=([BitConverter]::ToString($sha).Replace('-','')).Substring(0,24)
    return Join-Path $BackupRoot $key
}

function Assert-BoltgunSnapshot {
    param([string]$SnapshotPath,[string]$ProfileRoot,[string]$GameConfigRoot)
    $manifestPath=Join-Path $SnapshotPath 'manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "Missing snapshot manifest: $manifestPath" }
    $manifest=Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ($manifest.profileRoot -ne [IO.Path]::GetFullPath($ProfileRoot) -or
        $manifest.gameConfigRoot -ne [IO.Path]::GetFullPath($GameConfigRoot)) {
        throw 'Snapshot belongs to different profile/game roots.'
    }
    foreach ($item in $manifest.entries) {
        if (-not $item.existed) { continue }
        $path=Join-Path $SnapshotPath $item.file
        if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or
            (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $item.sha256) {
            throw "Snapshot file changed or missing: $path"
        }
    }
    return $manifest
}

function Save-BoltgunInstallSnapshot {
    param([object[]]$Entries,[string]$SnapshotPath,[string]$ProfileRoot,[string]$GameConfigRoot)
    if (Test-Path -LiteralPath $SnapshotPath) {
        $null=Assert-BoltgunSnapshot -SnapshotPath $SnapshotPath -ProfileRoot $ProfileRoot -GameConfigRoot $GameConfigRoot
        return
    }
    $staging=$SnapshotPath+'.pending-'+[guid]::NewGuid().ToString('N')
    New-Item -ItemType Directory -Path $staging -Force | Out-Null
    try {
        $records=@()
        $counter=0
        foreach ($entry in $Entries) {
            $exists=Test-Path -LiteralPath $entry.target -PathType Leaf
            $relative="files/$counter.bak"
            $hash=$null
            if ($exists) {
                New-Item -ItemType Directory -Path (Join-Path $staging 'files') -Force | Out-Null
                Copy-Item -LiteralPath $entry.target -Destination (Join-Path $staging $relative)
                $hash=(Get-FileHash -LiteralPath $entry.target -Algorithm SHA256).Hash
                if ((Get-FileHash -LiteralPath (Join-Path $staging $relative) -Algorithm SHA256).Hash -ne $hash) {
                    throw "Snapshot copy differs: $($entry.target)"
                }
            }
            $records+=@{ target=$entry.target; source=$entry.source; disabled=[bool]$entry.disabled; existed=$exists; sha256=$hash; file=$relative }
            $counter++
        }
        $manifest=@{version=2;profileRoot=[IO.Path]::GetFullPath($ProfileRoot);gameConfigRoot=[IO.Path]::GetFullPath($GameConfigRoot);entries=$records}
        [IO.File]::WriteAllText((Join-Path $staging 'manifest.json'),(($manifest | ConvertTo-Json -Depth 6)+"`n"),[Text.UTF8Encoding]::new($false))
        New-Item -ItemType Directory -Path (Split-Path -Parent $SnapshotPath) -Force | Out-Null
        Move-Item -LiteralPath $staging -Destination $SnapshotPath
    } finally {
        if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
    }
}
