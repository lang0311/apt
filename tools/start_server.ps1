# 팀 서버(apt 옆 team/)를 127.0.0.1:8000으로 켠다. VS Code에서 Ctrl+Shift+B.
# 이미 켜져 있으면 다시 켜지 않는다. 끌 때는 터미널에서 Ctrl+C.
$ErrorActionPreference = 'Stop'
$team = Resolve-Path (Join-Path $PSScriptRoot '..\..\team')
$python = Join-Path $team '.venv\Scripts\python.exe'
if (!(Test-Path -LiteralPath $python)) { throw "team/.venv가 없어요: $python" }

if (Get-NetTCPConnection -State Listen -LocalPort 8000 -ErrorAction SilentlyContinue) {
    Write-Host '서버가 이미 켜져 있어요: http://127.0.0.1:8000/docs'
    exit 0
}

$env:PYTHONUTF8 = '1'
$env:PYTHONUNBUFFERED = '1'
Write-Host '서버를 켜요: http://127.0.0.1:8000/docs (끄기: Ctrl+C)'
Set-Location $team
& $python -B -m uvicorn api:app --host 127.0.0.1 --port 8000
