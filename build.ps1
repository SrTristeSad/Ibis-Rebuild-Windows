param([string]$Compiler = '', [string]$Runtime = 'C:\Program Files\LOVE')
$ErrorActionPreference = 'Stop'
$buildArgs = @((Join-Path $PSScriptRoot 'tools\build.py'), 'all', '--runtime', $Runtime)
if ($Compiler) { $buildArgs += @('--compiler', $Compiler) }
& python @buildArgs
exit $LASTEXITCODE
