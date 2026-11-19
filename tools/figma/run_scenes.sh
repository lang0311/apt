#!/bin/bash
# Mock 모드로 흐름도 화면을 에뮬레이터에서 뽑는다.
# 사용: tools/figma/run_scenes.sh <로그이름> [flutter test 옵션...]   예) run_scenes.sh m1 --name "S[134]"
# 작업 폴더: $FIGMA_WORK (기본 build/figma_work), 기기: $FIGMA_DEVICE (기본 emulator-5554)
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
WORK="${FIGMA_WORK:-$ROOT/build/figma_work}"
DEV="${FIGMA_DEVICE:-emulator-5554}"
[ -n "${ANDROID_HOME:-}" ] && export PATH="$PATH:$ANDROID_HOME/platform-tools"
mkdir -p "$WORK/dump"
cd "$ROOT" || exit 1
LOG="$WORK/dump/$1.log"; shift
flutter test integration_test/_figma/scenes_mock.dart -d "$DEV" "$@" > "$LOG" 2>&1
grep -av "^FIGDUMP" "$LOG" | grep -a "DUMPED\|STEPFAIL\|SHOTFAIL\|\[E\]\|Some tests\|All tests" | cut -c1-220
PYTHONIOENCODING=utf-8 python "$HERE/parse_dump.py" "$LOG" "$WORK/dump" | grep -i "incomplete"
exit 0
