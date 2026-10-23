param([string]$Runtime = 'C:\Program Files\LOVE')
$ErrorActionPreference = 'Stop'
$runner = Join-Path $Runtime 'love.exe'
if (-not (Test-Path -LiteralPath $runner)) { throw 'Informe o diretório do runtime oficial LÖVE 11.5 x64.' }
& $runner (Join-Path $PSScriptRoot 'app')
exit $LASTEXITCODE
