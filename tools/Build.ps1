param([string]$DevCmd)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
if (-not $DevCmd) {
    $locator = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path -LiteralPath $locator)) { throw 'Install Visual Studio C++ Build Tools, or supply -DevCmd.' }
    $installation = & $locator -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (-not $installation) { throw 'No MSVC C++ toolchain found.' }
    $DevCmd = Join-Path $installation 'Common7\Tools\VsDevCmd.bat'
}
foreach ($module in @('muzzle','chainsword')) {
    & (Join-Path $repo "src\native\$module\Build.ps1") -DevCmd $DevCmd
}
# Build outputs have their own exact-byte hashes; preserve recognized upgrades.
$bolterPath = Join-Path $repo 'manifests\bolter3d.package.json'
$bolter = Get-Content -LiteralPath $bolterPath -Raw | ConvertFrom-Json
$newHash = (Get-FileHash -LiteralPath (Join-Path $repo $bolter.pluginSource)).Hash
if ($bolter.pluginSha256 -ne $newHash) {
    $bolter.pluginUpgradeFrom = @($bolter.pluginUpgradeFrom + $bolter.pluginSha256 | Select-Object -Unique)
    $bolter.pluginSha256 = $newHash
}
[IO.File]::WriteAllText($bolterPath, ($bolter | ConvertTo-Json -Depth 10)+"`n", [Text.UTF8Encoding]::new($false))
$chainPath = Join-Path $repo 'manifests\chainsword3d.package.json'
$chain = Get-Content -LiteralPath $chainPath -Raw | ConvertFrom-Json
$plugin = $chain.files | Where-Object target -eq 'plugins\boltgun_chainsword.dll'
$newHash = (Get-FileHash -LiteralPath (Join-Path $repo $plugin.source)).Hash
if ($plugin.sha256 -ne $newHash) {
    $plugin.upgradeFrom = @($plugin.upgradeFrom + $plugin.sha256 | Select-Object -Unique)
    $plugin.sha256 = $newHash
}
[IO.File]::WriteAllText($chainPath, ($chain | ConvertTo-Json -Depth 10)+"`n", [Text.UTF8Encoding]::new($false))
$deploymentPath = Join-Path $repo 'deployment.json'
$deployment = Get-Content -LiteralPath $deploymentPath -Raw | ConvertFrom-Json
foreach ($entry in $deployment | Where-Object source -like 'build\plugins\*') {
    $entry.sha256 = (Get-FileHash -LiteralPath (Join-Path $repo $entry.source)).Hash
}
[IO.File]::WriteAllText($deploymentPath, ($deployment | ConvertTo-Json -Depth 10)+"`n", [Text.UTF8Encoding]::new($false))
