# Shared portable paths. Loading this file never writes to the installed profile.
function Resolve-BoltgunSteamBindingRoot {
    $steamPath = (Get-ItemProperty -LiteralPath 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
    if (-not $steamPath) { $steamPath = Join-Path ${env:ProgramFiles(x86)} 'Steam' }
    return Join-Path $steamPath 'config\openxr'
}

function Get-BoltgunDeployment {
    param([string]$RepositoryRoot, [string]$ProfileRoot, [string]$GameConfigRoot)
    $entries = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'deployment.json') -Raw | ConvertFrom-Json
    foreach ($entry in $entries) {
        if ($entry.target.StartsWith('${ProfileRoot}\')) {
            $allowedRoot = $ProfileRoot
            $relative = $entry.target.Substring('${ProfileRoot}\'.Length)
        } elseif ($entry.target.StartsWith('${GameConfigRoot}\')) {
            $allowedRoot = $GameConfigRoot
            $relative = $entry.target.Substring('${GameConfigRoot}\'.Length)
        } else { throw "Destino desconocido: $($entry.target)" }
        $allowedPrefix = [IO.Path]::GetFullPath($allowedRoot).TrimEnd('\') + '\'
        $resolved = [IO.Path]::GetFullPath((Join-Path $allowedRoot $relative))
        if (-not $resolved.StartsWith($allowedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Destino fuera de la raiz permitida: $resolved"
        }
        $entry.target = $resolved
    }
    return $entries
}
