$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $root
try {
    python tools/assemble_lua.py --check
    if ($LASTEXITCODE -ne 0) { throw "Falha na montagem Lua" }
    $stage = Join-Path $root 'build/lua-app'
    $output = Join-Path $root 'build/IbisLua-Windows.love'
    if (Test-Path $output) { Remove-Item $output -Force }
    $zip = Join-Path $root 'build/IbisLua-Windows.zip'
    if (Test-Path $zip) { Remove-Item $zip -Force }
    Compress-Archive -Path "$stage/*" -DestinationPath $zip -Force
    Move-Item $zip $output -Force
    Write-Host "Pacote Lua/LÖVE criado: $output"
} finally { Pop-Location }
