#!/usr/bin/env bash
# 개인 레포 main의 커밋된 내용을 팀 레포 mobile/에 맞추고 스테이징까지만 한다.
# 커밋·push는 하지 않는다 (결과 확인 후 직접).
# 사용: bash tools/sync_team.sh [팀 레포 경로]   (기본: 이 레포 기준 ../../team)
set -euo pipefail

APP="$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)"
TEAM="${1:-$APP/../../team}"

if [ -n "$(git -C "$APP" status --porcelain)" ]; then
  echo "주의: 개인 레포에 커밋 안 한 변경이 있음 — main에 커밋된 내용만 반영됨"
fi

[ "$(git -C "$TEAM" branch --show-current)" = "main" ] || { echo "중단: 팀 레포가 main이 아님"; exit 1; }
[ -z "$(git -C "$TEAM" status --porcelain)" ] || { echo "중단: 팀 레포에 정리 안 된 변경이 있음"; exit 1; }
git -C "$TEAM" pull -q --ff-only

# 팀 레포 mobile/은 개인 레포의 복사본이라 통째로 비우고(무시 대상 포함) main 내용으로 다시 채운다
git -C "$TEAM" ls-files -z mobile | (cd "$TEAM" && xargs -0 rm -f)
git -C "$TEAM" clean -q -f -d -x -- mobile
git -C "$APP" archive --format=tar --prefix=mobile/ main | tar -x -C "$TEAM"
git -C "$TEAM" add -A mobile

STAGED="$(git -C "$TEAM" diff --cached --name-status)"
echo "개인 레포 main: $(git -C "$APP" log --oneline -1 main)"
echo "팀 레포 main:   $(git -C "$TEAM" log --oneline -1)"
if [ -z "$STAGED" ]; then
  echo "바뀐 파일 없음"
  exit 0
fi
echo "추가 $(grep -c '^A' <<<"$STAGED" || true) / 수정 $(grep -c '^M' <<<"$STAGED" || true) / 삭제 $(grep -c '^D' <<<"$STAGED" || true)"
echo "mobile/ 밖 변경: $(cut -f2- <<<"$STAGED" | grep -vc '^"\?mobile/' || true)"
echo "키·일지·스킬 파일: $(grep -E '^[AM]' <<<"$STAGED" | cut -f2- | grep -cE 'config/dev\.json|Secrets\.xcconfig|local\.properties|devlog|08_DEV_LOG|\.agents/|skills-lock' || true)"
echo "---"
echo "$STAGED"
