# apt
졸업프로젝트 레포지토리 입니다

인스타그램 릴스 등에서 **공유**로 장소를 보내면 자동으로 추출·저장하고, 저장한 장소로 AI가 코스를 만들어 주는 Flutter 앱입니다.
카피: "가고 싶은 곳을, 하나의 코스로."

- 개발 가이드: [`CLAUDE.md`](CLAUDE.md), [`docs/`](docs/README.md)
- UI 시안: `design/ui/` (34화면)

## 실행

```bash
flutter pub get
flutter run                                   # Mock 데이터 (기본)
flutter run --dart-define=MOCK_SCENARIO=empty # 빈 상태 확인
flutter run --dart-define=MOCK_SCENARIO=error # 오류 상태 확인
flutter run --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=https://...  # 실서버 (API 명세 수령 후)
```

| dart-define | 기본값 | 설명 |
|---|---|---|
| `USE_MOCK` | `true` | Mock Repository 사용 |
| `MOCK_SCENARIO` | `normal` | `normal` / `empty` / `error` |
| `MOCK_LATENCY_MS` | `600` | Mock 응답 지연 |
| `API_BASE_URL` | – | 백엔드 주소 (NEEDS BACKEND) |
| `NAVER_MAP_CLIENT_ID` | – | 네이버 지도 클라이언트 ID (없으면 지도 미리보기) |
| `EMAIL_AUTH` | `false` | 이메일 로그인 노출 (틀만 구현) |

### Mock으로 흐름 확인하기
- 로그인: 카카오 = 신규 가입 흐름, Google = 기존 회원, Apple = 계정 충돌
- 추출 URL: `private` 포함 = 비공개, `none` = 장소 없음, `fail` = 실패
- 초대 토큰: `/invites/expired`, `/invites/joined`, `/invites/full` = 예외 상태
