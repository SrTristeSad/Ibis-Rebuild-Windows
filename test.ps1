$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $root
try {
    python tools/assemble_lua.py --check
    if ($LASTEXITCODE -ne 0) { throw "Falha na montagem Lua" }
    python tests/test_lua_integration.py
    if ($LASTEXITCODE -ne 0) { throw "Falha nos testes de integração" }
    Write-Host "Teste de pixels do LÖVE: executado no CI Windows."
} finally { Pop-Location }
