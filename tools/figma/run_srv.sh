#!/bin/bash
# 서버 모드(팀 서버 연결)로 흐름도 화면을 뽑는다. 팀 서버를 먼저 켜 둔다(tools/start_server.ps1).
# 계정은 환경 변수로만 받는다: APT_DEMO_USER, APT_DEMO_PW (코드 · 로그에 남기지 않는다).
# 사용: tools/figma/run_srv.sh <로그이름> [flutter test 옵션...]   예) run_srv.sh s1 --name "V[1-3]"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
WORK="${FIGMA_WORK:-$ROOT/build/figma_work}"
DEV="${FIGMA_DEVICE:-emulator-5554}"
API="${FIGMA_API_BASE_URL:-http://10.0.2.2:8000}"
: "${APT_DEMO_USER:?APT_DEMO_USER 환경 변수가 필요해요}"
: "${APT_DEMO_PW:?APT_DEMO_PW 환경 변수가 필요해요}"
[ -n "${ANDROID_HOME:-}" ] && export PATH="$PATH:$ANDROID_HOME/platform-tools"
mkdir -p "$WORK/dump_srv"
cd "$ROOT" || exit 1
LOG="$WORK/dump_srv/$1.log"; shift
flutter test integration_test/_figma/scenes_server.dart -d "$DEV" \
  --dart-define=APT_BACKEND=true --dart-define=USE_MOCK=false --dart-define=API_BASE_URL="$API" \
  --dart-define=FIGMA_USER="$APT_DEMO_USER" --dart-define=FIGMA_PW="$APT_DEMO_PW" "$@" > "$LOG" 2>&1
# 로그에는 비밀번호가 찍히지 않지만, 혹시 몰라 dart-define 줄은 남기지 않는다
grep -av "^FIGDUMP" "$LOG" | grep -a "DUMPED\|STEPFAIL\|SHOTFAIL\|\[E\]\|Some tests\|All tests" | cut -c1-220
PYTHONIOENCODING=utf-8 python "$HERE/parse_dump.py" "$LOG" "$WORK/dump_srv" | grep -i "incomplete"
exit 0
