# 팀 서버(team/)를 추천 한도를 올려서 띄운다. 팀 레포 코드는 건드리지 않고 환경 변수만 바꾼다.
#   하루 호출 수 : APT_DAILY_CALL_LIMIT (서버 기본 24)
#   하루 금액    : APT_DAILY_USD_LIMIT  (서버 기본 10 달러, 실제 비용 + 진행 중 예약 합계 기준)
# 사용: powershell -ExecutionPolicy Bypass -File scripts\run-server-high-limit.ps1 [-Calls 100] [-Usd 20]
# 8000번에서 이미 돌고 있는 서버가 있으면 끄고 새로 띄운다.
param(
  [int]$Calls = 100,
  [double]$Usd = 20
)

$team = Join-Path $PSScriptRoot '..\..\team' | Resolve-Path
$python = Join-Path $team '.venv\Scripts\python.exe'
if (!(Test-Path -LiteralPath $python)) { throw "team\.venv 파이썬이 없습니다: $python" }

$old = Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue
foreach ($c in $old) {
  Write-Host "8000번 서버(PID $($c.OwningProcess))를 끕니다"
  Stop-Process -Id $c.OwningProcess -Force -ErrorAction SilentlyContinue
}

$env:PYTHONUTF8 = '1'
$env:PYTHONUNBUFFERED = '1'
$env:APT_DAILY_CALL_LIMIT = "$Calls"
$env:APT_DAILY_USD_LIMIT = "$Usd"

Write-Host "추천 한도: 하루 $Calls 회 / $Usd 달러 (사용자별)"
Set-Location $team
& $python -B -m uvicorn api:app --host 127.0.0.1 --port 8000
