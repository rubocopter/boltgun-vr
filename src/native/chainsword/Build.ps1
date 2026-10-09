param([Parameter(Mandatory=$true)][string]$DevCmd, [switch]$TestsOnly)
$ErrorActionPreference='Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$output = Join-Path $repo 'build\chainsword'
$plugins = Join-Path $repo 'build\plugins'
New-Item -ItemType Directory -Path $output,$plugins -Force | Out-Null
Push-Location $PSScriptRoot
try {
    foreach($name in @('test_mesh','test_bridge')) {
        $exe = Join-Path $output ($name+'.exe')
        $obj = Join-Path $output ($name+'.obj')
        $command='"'+$DevCmd+'" -arch=x64 -host_arch=x64 >nul && cl /nologo /std:c++17 /EHsc /W4 /WX "'+$name+'.cpp" /Fo:"'+$obj+'" /Fe:"'+$exe+'" /link /IMPLIB:"'+(Join-Path $output ($name+'.lib'))+'"'
        & cmd.exe /d /c $command
        if($LASTEXITCODE -ne 0){throw "Native compilation failed: $name"}
        & $exe
        if($LASTEXITCODE -ne 0){throw "Native tests failed: $name"}
    }
    if(-not $TestsOnly) {
        $command='"'+$DevCmd+'" -arch=x64 -host_arch=x64 >nul && cl /nologo /std:c++17 /EHsc /W4 /WX /O2 /MT /LD boltgun_chainsword.cpp /Fo:"'+(Join-Path $output 'boltgun_chainsword.obj')+'" /Fe:"'+(Join-Path $plugins 'boltgun_chainsword.dll')+'" /link /Brepro /IMPLIB:"'+(Join-Path $output 'boltgun_chainsword.lib')+'"'
        & cmd.exe /d /c $command
        if($LASTEXITCODE -ne 0){throw 'Native plugin compilation failed.'}
    }
} finally {Pop-Location}
