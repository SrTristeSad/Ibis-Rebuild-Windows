param([string]$Runtime = 'C:\Program Files\LOVE')
$ErrorActionPreference = 'Stop'
$runner = Join-Path $Runtime 'lovec.exe'
if (-not (Test-Path -LiteralPath $runner)) {
    throw 'LÖVE 11.5 x64 nao encontrado; informe -Runtime.'
}
$env:IBIS_PROJECT_ROOT = $PSScriptRoot
$env:IBIS_LOVE_RUNTIME = $Runtime
& $runner (Join-Path $PSScriptRoot 'tools\lua_builder')
if ($LASTEXITCODE -ne 0) { throw "Build Lua falhou: $LASTEXITCODE" }
