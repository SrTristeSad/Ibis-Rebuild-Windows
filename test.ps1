param(
    [string]$Runtime = 'C:\Program Files\LOVE'
)
$ErrorActionPreference = 'Stop'
$runner = Join-Path $Runtime 'lovec.exe'
if (-not (Test-Path -LiteralPath $runner)) {
    throw 'LÖVE 11.5 x64 (lovec.exe) nao encontrado.'
}
$env:IBIS_PROJECT_ROOT = $PSScriptRoot
& $runner (Join-Path $PSScriptRoot 'tools\lua_tests') $PSScriptRoot
if ($LASTEXITCODE -ne 0) { throw "Suite Lua falhou: $LASTEXITCODE" }
