param(
    [ValidateSet('all','lua','native','ui')][string]$Suite = 'all',
    [string]$Runtime = 'C:\Program Files\LOVE'
)
$ErrorActionPreference = 'Stop'
& python (Join-Path $PSScriptRoot 'tools\test.py') --suite $Suite --runtime $Runtime
exit $LASTEXITCODE
