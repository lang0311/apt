# APT 모바일 앱 (Flutter)

인스타그램 릴스 등에서 **공유**로 장소를 보내면 자동으로 찾아 저장하고, 저장한 장소로 AI가 코스(파티 취향 반영)를 만들어 주는 앱입니다.
카피: "가고 싶은 곳을, 하나의 코스로."

- 팀 레포에서는 이 폴더가 `mobile/`입니다. 백엔드(Python)는 팀 레포 루트(`api.py`, `src/`)에 있습니다.
- 앱은 백엔드 API를 쓰는 쪽입니다. 서버에 아직 없는 기능은 앱 안의 Mock 데이터로 동작합니다.

---

## 1. 빠르게 실행하기 (서버 없이, Mock)

서버 · 키 없이 모든 화면을 볼 수 있는 가장 쉬운 방법입니다.

```bash
cd mobile          # 팀 레포 기준. 개인 레포는 레포 루트
flutter pub get
flutter run        # 연결된 에뮬레이터/기기에서 실행
```

- 웹으로 보려면 `flutter run -d chrome`
- 로그인 화면에서 **Google 아이콘**을 누르면 기존 회원으로 바로 들어갑니다(Mock). 다른 방법은 [5. Mock에서 흐름 확인하기](#5-mock에서-흐름-확인하기).

---

## 2. 준비물

| 항목 | 내용 |
|------|------|
| Flutter | **3.35.5 이상** (Dart `^3.9.2`). 3.35.5 · 3.47.7에서 확인함. `flutter doctor`로 점검 |
| Android | Android Studio + Android SDK + 에뮬레이터. 확인한 기기: Pixel 6 Pro 에뮬레이터(그래픽은 `Hardware`/`host`. `Software`로 두면 앱이 꺼질 수 있음) |
| 웹 | Chrome (서버 연결 웹 실행용) |
| 편집기 | VS Code + Flutter 확장 권장 (실행 설정이 `.vscode/launch.json`에 있음) |
| 서버 연결 시 | Python 3.12 이상 + 팀 레포 루트의 서버 설정 ([4. 서버에 연결해서 실행하기](#4-서버에-연결해서-실행하기)) |
| iOS | 아직 검증하지 않았습니다 (Mac 필요) |

---

## 3. 키 파일 (`config/dev.json`, 선택)

지도 · 소셜 로그인 키를 넣는 파일입니다. **커밋하지 않습니다**(`.gitignore`에 들어 있음).
키가 없어도 앱은 돌아갑니다. 지도는 미리보기 그림으로, 소셜 로그인은 Mock으로 대신합니다.

```bash
cp config/dev.example.json config/dev.json     # Windows PowerShell: Copy-Item config/dev.example.json config/dev.json
```

| 키 | 쓰는 곳 | 없으면 |
|----|---------|--------|
| `NAVER_MAP_CLIENT_ID` | 네이버 지도(Android) | 지도 미리보기 그림 |
| `KAKAO_NATIVE_APP_KEY` | 카카오 로그인 | Mock 로그인 |
| `GOOGLE_SERVER_CLIENT_ID` · `GOOGLE_IOS_CLIENT_ID` | Google 로그인 | Mock 로그인 |
| `USE_MOCK` | Mock 사용 여부 | 기본 `true` |

- 키 값은 팀원에게 따로 받습니다. 채팅 · 이슈 · 커밋에 붙여 넣지 않습니다.
- 키를 넣고 실행하면 Google 아이콘을 눌렀을 때 **실제 Google 로그인 창**이 뜹니다. Mock 흐름만 보려면 키 없이(또는 `dev.json` 없이) 실행하세요.
- 키 파일을 쓰는 실행: `flutter run --dart-define-from-file=config/dev.json`

---

## 4. 서버에 연결해서 실행하기

아이디 가입 · 로그인, 장소 검색 · 저장, AI 코스 추천, 파티 · 초대는 실제 팀 서버로 동작합니다.

### 4-1. 서버 켜기 (팀 레포 루트, Windows PowerShell)

처음 한 번:

```powershell
cd <팀 레포 루트>
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-server.txt
if (!(Test-Path .env)) { Copy-Item .env.example .env }   # 그다음 .env에 키 입력
```

| `.env` 키 | 필요한 기능 |
|-----------|-------------|
| `OPENROUTER_API_KEY` | AI 코스 추천 |
| `KAKAO_API_KEY` | 장소 검색 · 선택 장소 확인 |
| 나머지 | 선택 사항 (팀 레포 루트 `README.md` 참고) |

켜기 (매번):

```powershell
.\.venv\Scripts\python.exe -m uvicorn api:app --host 127.0.0.1 --port 8000
```

- 켜졌는지 확인: 브라우저에서 http://127.0.0.1:8000/docs 가 열리면 됩니다.
- 키가 없어도 가입 · 로그인 · 코스 목록 · 파티는 됩니다. 장소 검색은 `KAKAO_API_KEY`, 추천은 `OPENROUTER_API_KEY`가 있어야 합니다.

### 4-2. 앱 실행 — 방법 셋 중 하나

**A. Android 에뮬레이터** (에뮬레이터에서 PC는 `10.0.2.2`)

```bash
flutter run --dart-define=APT_BACKEND=true --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=http://10.0.2.2:8000 --dart-define-from-file=config/dev.json
```

**B. Chrome 웹** (서버가 `127.0.0.1:5173`만 허용하므로 포트 · 주소를 꼭 맞춤)

```bash
flutter run -d chrome --web-hostname=127.0.0.1 --web-port=5173 --dart-define=APT_BACKEND=true --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=http://127.0.0.1:8000 --dart-define-from-file=config/dev.json
```

**C. 팀 레포 루트의 `run.cmd`** (웹 빌드 + 서버 실행을 한 번에)

- `run.cmd`를 더블클릭하면 앱을 웹으로 빌드하고 서버를 켭니다. 그다음 http://127.0.0.1:8000/mobile-app/ 에서 앱을 엽니다.
- Flutter SDK를 `%USERPROFILE%\develop\flutter`에서 찾고, Python은 팀 레포 루트의 `.venv`를 씁니다.
- 손으로 빌드할 때는 **PowerShell에서** 실행하세요(Git Bash는 `/mobile-app/`을 파일 경로로 바꿔 버립니다).
  `flutter build web --base-href /mobile-app/ --dart-define=APT_BACKEND=true --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=http://127.0.0.1:8000`

> `config/dev.json`이 없으면 각 명령에서 `--dart-define-from-file=config/dev.json`만 빼고 실행하세요. 서버 연결은 그대로 됩니다.

### 4-3. VS Code로 실행

실행 및 디버그(F5) 목록에서 고릅니다.

| 설정 이름 | 하는 일 |
|-----------|---------|
| `apt (dev)` | Mock + `config/dev.json` 키 |
| `apt (서버 연결, 에뮬레이터)` | 4-2 A와 같음 |
| `apt (서버 연결, 웹)` | 4-2 B와 같음 |
| `apt (dev, profile)` | 성능 확인용 profile 모드 |

### 4-4. 서버 모드에서 되는 것 / 안 되는 것

| 서버로 동작 | 아직 Mock 또는 준비 중 (서버에 API 없음) |
|-------------|------------------------------------------|
| 아이디 가입 · 로그인 · 로그아웃 · 자동 로그인 | 소셜 로그인 (누르면 앱 안 Mock 데이터로 들어감) |
| 홈 요약, 저장한 장소 · 카테고리 | 보관함 만들기 · 담기 |
| 지도에서 장소 검색 · 저장 | 릴스 링크로 장소 찾기 |
| AI 코스 추천(단계 표시 · 취소) · 다시 추천 · 장소 빼기 · 차단 | 약관 동의 기록, 프로필 수정, 취향 직접 고르기 |
| 코스 저장 · 목록 · 상세 | 저장한 코스 편집 (서버가 저장과 함께 확정해서 수정 불가) |
| 파티 만들기 · 초대 링크 · 참여 · 기존 파티 고르기 | 추천 코스 · 지금 뜨는 장소, 알림 |

자세한 연동 상태는 `docs/06_API_INTEGRATION.md` §0, 서버 실행 메모는 `docs/LOCAL_BACKEND.md`.

---

## 5. Mock에서 흐름 확인하기

서버 없이 상태별 화면을 볼 수 있게 정해 둔 규칙입니다.

| 확인할 것 | 방법 |
|-----------|------|
| 기존 회원으로 로그인 | 로그인 화면 **Google** 아이콘 |
| 신규 가입 흐름 (약관 → 프로필 → 가입 완료) | **카카오** 아이콘 |
| 아이디 로그인 | 아이디 아무거나 + 비밀번호 `password1` (그 밖의 비밀번호는 오류 화면) |
| 아이디 가입 중복 오류 | 아이디 `taken` |
| 닉네임 중복 오류 | 닉네임 `관리자` |
| 링크 추출 실패 상태 | 추출 탭에서 링크에 `private`(비공개) · `none`(장소 없음) · `fail`(실패)을 넣기 |
| 초대 예외 화면 | 초대 링크 `/invites/expired` · `/invites/joined` · `/invites/full` |
| 빈 상태 / 오류 상태 전체 | `flutter run --dart-define=MOCK_SCENARIO=empty` / `=error` |

Apple 로그인과 이메일 로그인은 숨겨져 있습니다(`APPLE_AUTH`, `EMAIL_AUTH`).

---

## 6. 실행 옵션 (`--dart-define`)

| 이름 | 기본값 | 설명 |
|------|--------|------|
| `APT_BACKEND` | `false` | `true`면 팀 서버(Python)에 연결 |
| `USE_MOCK` | `true` | 서버 연결 시 `false` |
| `API_BASE_URL` | – | 서버 주소. 에뮬레이터 `http://10.0.2.2:8000`, 웹 · PC `http://127.0.0.1:8000` |
| `MOCK_SCENARIO` | `normal` | `normal` / `empty` / `error` |
| `MOCK_LATENCY_MS` | `600` | Mock 응답 지연(ms) |
| `NAVER_MAP_CLIENT_ID` | – | 네이버 지도 |
| `KAKAO_NATIVE_APP_KEY` | – | 카카오 로그인 |
| `GOOGLE_SERVER_CLIENT_ID` · `GOOGLE_IOS_CLIENT_ID` | – | Google 로그인 |
| `EMAIL_AUTH` · `APPLE_AUTH` | `false` | 숨긴 로그인 방법 보이기(개발용) |

---

## 7. 테스트

```bash
flutter analyze                                   # 정적 분석 (문제 0개 유지)
flutter test                                      # 단위 · 위젯 테스트 (360·430 폭 화면 깨짐 확인 포함)
flutter test integration_test -d emulator-5554    # 에뮬레이터에서 주요 흐름 A–L 끝까지 (Mock)
```

- 통합 테스트는 에뮬레이터가 켜져 있어야 합니다. 기기 이름은 `flutter devices`로 확인합니다.
- 흐름 A–L: 신규 가입, 계정 연결, 저장됨, 보관함, 추출 성공 · 실패, 코스 만들기, 코스 편집, 마이 · 취향, 초대 수락, 아이디 가입 · 로그인.

---

## 8. 자주 막히는 것

| 증상 | 해결 |
|------|------|
| 웹에서 로그인이 유지되지 않음 | 주소를 `127.0.0.1`로 통일 (`localhost`와 섞으면 쿠키가 따로 저장됨) |
| 웹에서 서버 요청이 막힘(CORS) | `--web-hostname=127.0.0.1 --web-port=5173`으로 실행 |
| 에뮬레이터에서 서버 연결 안 됨 | `API_BASE_URL=http://10.0.2.2:8000` 인지, PC에서 서버가 켜져 있는지 확인 |
| `/mobile-app/`이 404 | 예전 서버가 켜져 있음 → 종료하고 `run.cmd` 다시 실행 |
| 지도가 그림으로 나옴 | `NAVER_MAP_CLIENT_ID` 없이 실행한 것 (정상). 웹은 OpenStreetMap 지도 |
| 에뮬레이터에서 앱이 바로 꺼짐 | 에뮬레이터 그래픽 설정을 `Hardware`(host)로 |
| 장소 검색 · 추천이 실패 | 서버 `.env`의 `KAKAO_API_KEY` · `OPENROUTER_API_KEY` 확인 |
| Google 아이콘이 실제 로그인 창을 띄움 | `config/dev.json`에 Google 키가 있어서 그럼. Mock만 볼 거면 키 없이 실행 |

---

## 9. 폴더와 문서

```
lib/
  app/        라우터 · 테마(토큰) · DI
  core/       공통 위젯 · 네트워크 · 설정(Env, FeatureFlags) · 유틸
  features/   auth · home · extraction · saved · place · course · party · preference · my · platform(팀 서버 연결)
  dev/mock/   Mock 데이터
test/  integration_test/  config/  design/ui/(원래 시안 34화면)  docs/
```

| 문서 | 내용 |
|------|------|
| `CLAUDE.md` | 개발 규칙 요약 (먼저 읽기) |
| `docs/README.md` | 문서 목록 |
| `docs/02_APP_DEVELOPMENT.md` | 구조 · 인증 · 공유 수신 · 지도 · 개발 단계 |
| `docs/03_DESIGN_SYSTEM.md` | 색 · 글자 · 컴포넌트 · 디자인 원칙 |
| `docs/05_SCREEN_SPEC.md` | 화면별 명세 |
| `docs/06_API_INTEGRATION.md` | API 연동 상태 · Mock · 백엔드에 필요한 것 |
| `docs/07_DECISIONS_AND_OPEN_ITEMS.md` | 정해진 결정 · 결정 대기 |
| `docs/LOCAL_BACKEND.md` | 서버 연결 상세 |
