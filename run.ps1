$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $root
try {
    python tools/assemble_lua.py --check
    if ($LASTEXITCODE -ne 0) { throw "Falha na montagem Lua" }
    $love = Get-Command love.exe -ErrorAction SilentlyContinue
    if (!$love -and $env:LOVE_RUNTIME) {
        $candidate = Join-Path $env:LOVE_RUNTIME 'love.exe'
        if (Test-Path $candidate) { $love = @{ Source = $candidate } }
    }
    if (!$love) { throw "Instale LÖVE 11.5 e coloque love.exe no PATH (ou LOVE_RUNTIME)." }
    & $love.Source (Join-Path $root 'build/lua-app')
    if ($LASTEXITCODE -ne 0) { throw "LÖVE encerrou com erro: $LASTEXITCODE" }
} finally { Pop-Location }
