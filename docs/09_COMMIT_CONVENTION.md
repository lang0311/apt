# 09. 커밋 메시지 규칙

> 기준일: 2026-10-19. 이 날짜 이후 모든 커밋에 적용한다. 이전 커밋(`문서: …`, `지도: …` 형식)은 이미 공개 레포에 push되어 다시 쓰지 않는다.

## 형식

```
type: 상세 내용

(선택) 본문 — 왜 바꿨는지, 남은 일, NEEDS BACKEND 등
```

- 첫 줄은 **`type: 상세 내용`** 한 줄. 콜론 뒤 한 칸 띄운다.
- `type`은 아래 목록의 영어 소문자만 쓴다.
- 상세 내용은 **한국어**로, 무엇을 바꿨는지 구체적으로 쓴다. 끝에 마침표를 찍지 않는다.
- 본문은 필요할 때만 빈 줄 뒤에 쓴다.
- AI 도구(Claude 등)의 `Co-Authored-By` 줄은 **팀 레포 커밋에는 넣지 않는다** (개인 레포 커밋에만 붙인다).
- **바꾼 내용만 담백하게** 쓴다. "개발 일지 n단계", "#nn" 같은 작업 단계·내부 번호는 첫 줄과 본문 어디에도 쓰지 않는다. 개발 일지를 함께 갱신해도 메시지에 적지 않는다.
  - 예: ~~`chore: 팀 레포 통합 대비 data/ 무시 해제, 개발 일지 20단계`~~ → `chore: 팀 레포 mobile/ 통합 대비 data/, .vscode/ 무시 해제`

## type 목록

| type | 쓰는 경우 | 예시 |
|------|-----------|------|
| `add` | 새 기능 · 화면 · 컴포넌트 · 파일 추가 | `add: 장소 상세에 네이버 지도 열기 버튼 추가` |
| `fix` | 버그 수정 | `fix: 카카오 로그인 취소 시 오류 화면 대신 로그인 화면 유지` |
| `refactor` | 동작은 그대로, 구조·코드만 개선 | `refactor: 위저드 StepHeader를 공통 컴포넌트로 분리` |
| `docs` | 문서 · 개발 일지 (`docs/`, `CLAUDE.md`, `tools/devlog/entries.js` — 일지는 개인 레포에만) | `docs: 07에 D11 출시 순서 결정 추가` |
| `chore` | 설정 · 도구 · 의존성 · 빌드 (gitignore, `.vscode`, 패키지 추가 등) | `chore: geolocator 패키지 추가` |
| `test` | 테스트 추가 · 수정 | `test: 저장 지도 권한 거부 시나리오 추가` |
| `style` | 포맷 · UI 문구 · 색/간격만 변경 (로직 변화 없음) | `style: 추출 안내 문구를 공유 경로 기준으로 변경` |

여러 종류가 섞이면 **주된 변경 하나**로 type을 정하고, 가능하면 커밋을 나눈다.

## 커밋 단위

- 화면 하나 / 컴포넌트 묶음 하나 단위로 작게 커밋하고 push한다 (단계 전체를 한 번에 커밋하지 않는다).
- 단계를 마치면 개발 일지(`tools/devlog/entries.js` → `docs/08_DEV_LOG.docx`)를 갱신해 함께 올린다. 커밋 메시지에는 일지·단계 번호를 적지 않는다.

## 팀 레포 반영

개발과 커밋은 **개인 레포 `lang0311/apt`** 에서 한다. 팀 레포(`jim-min/Agentic-Personal-Travelassistant`)의 `mobile/`에는 큰 기능 추가·수정·개선이 끝날 때마다 한 번에 반영한다.

- 팀 레포의 `mobile/`은 직접 수정하지 않는다. 항상 개인 레포에서 고친 뒤 반영한다.
- 반영: `bash tools/sync_team.sh` → 개인 레포 `main`의 커밋된 내용을 팀 레포 `mobile/`에 맞추고 스테이징까지만 한다 (커밋·push 안 함).
- 개발 일지, `.agents/`, `skills-lock.json`, 반영 도구 자체는 `.gitattributes`의 `export-ignore`로 팀 레포에 들어가지 않는다.
- 결과(바뀐 파일, `mobile/` 밖 변경 0개, 키 파일 없음)를 확인한 뒤 기능 요약 메시지로 커밋하고 팀 레포 `main`에 push한다. 예: `add: AI 추천 API 연동, 장소 검색 화면`

## 커밋 금지

레포는 **공개(public)** 상태다. 아래는 절대 커밋하지 않는다.

- `config/dev.json`, `ios/Flutter/Secrets.xcconfig`, `android/local.properties`, `.env` (gitignore 대상)
- 릴리스 키스토어(`.jks`, `.keystore`), `key.properties`
- Secret · Admin 키 · 비밀번호 (네이버 Client Secret, 카카오 Admin/REST 키, Google Client Secret 등)
- 개발 일지 · 문서 · 커밋 메시지에도 키 **값**은 적지 않는다 (어디서 관리하는지만 적는다)

### 커밋 전 키 검사

커밋할 때마다 `tools/hooks/pre-commit`이 스테이징된 파일·추가된 줄에서 키 파일과 키 형식(OpenRouter·Google·GitHub·AWS 키, 개인 키, `*_KEY=`·`SECRET=`·`PASSWORD=` 등)을 찾고, 있으면 커밋을 멈춘다. 값은 출력하지 않고 위치만 보여 준다.

- 설치(clone마다 한 번): `cp tools/hooks/pre-commit .git/hooks/pre-commit`
- 걸리면 값을 gitignore 대상 파일로 옮긴다. `--no-verify`로 넘기지 않는다.
