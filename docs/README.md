# APT 프로젝트 문서 인덱스

> 새 Codex Work / 개발 세션은 **이 파일부터 읽는다.**
> 기준일: 2026-10-03 · 클라이언트: Flutter · 백엔드/AI: 외부 제공(API 소비자)

## 문서 구성

| 파일 | 주제 | 언제 읽나 |
|------|------|-----------|
| [01_PROJECT_PURPOSE.md](01_PROJECT_PURPOSE.md) | 서비스 목적 · 핵심 가치 · 책임 분담 | 항상 (가장 먼저) |
| [02_APP_DEVELOPMENT.md](02_APP_DEVELOPMENT.md) | Flutter 앱 개발: 아키텍처 · 인증 · 공유 수신 · 지도 · 개발 단계 · 작업 규칙 | 코드 작성 전 |
| [03_DESIGN_SYSTEM.md](03_DESIGN_SYSTEM.md) | 디자인 프레임 정책 · 토큰 · 컴포넌트 · 새 화면 디자인 원칙 | UI 구현/신규 디자인 시 |
| [04_UX_FLOWS.md](04_UX_FLOWS.md) | 사용자 흐름: 인증 · 공유 추출 · 저장 · 코스 루프 · 파티 · 취향 | 화면 연결/네비게이션 구현 시 |
| [05_SCREEN_SPEC.md](05_SCREEN_SPEC.md) | 화면 34개 명세 (라우트 · UI · 데이터 · 상태) | 화면 단위 구현 시 |
| [06_API_INTEGRATION.md](06_API_INTEGRATION.md) | 백엔드 연동 원칙 · 필요 데이터 목록 · Mock 전략 | API 연동/백엔드 협의 시 |
| [07_DECISIONS_AND_OPEN_ITEMS.md](07_DECISIONS_AND_OPEN_ITEMS.md) | 확정 사항 로그 · 가정 · 미해결 항목 | 막혔을 때 / 범위 확인 시 |

## 한눈에 보는 확정 사항 (2026-10-03)

1. 앱은 **Flutter**, 백엔드/API/AI는 **제공받는다**. 앱은 API 소비자.
2. **핵심 진입은 인스타그램 릴스 "공유" → 우리 앱**. 앱 안의 링크 입력 화면은 SNS 주소를 이미 알 때 쓰는 **보조 경로**.
3. 로그인은 **소셜 로그인 전용**. 단, **이메일 로그인 "틀"만 만들어 둔다** (feature flag로 숨김, 예외 화면은 간단히).
4. 코스 만들기: **정보 → 장소 → 동행 → AI 추천 → (장소 수정 → AI 재추천) 반복 가능**.
5. 지도 SDK는 **네이버 지도**로 확정.
6. 취향 설정 화면은 기존 UI 디자인 언어를 유지해 **새로 디자인함** (`ui_additions/`).
7. 디자인 프레임 390×844는 **참고 기준**일 뿐, 개발은 **반응형**으로 한다 (03 문서 참고).

## 자료 위치

```
canonical_user_flow_ui_svgs/      ← 기존 31개 화면 + 흐름도 (PREVIEWS 먼저 확인)
ui_additions/                     ← 이번에 추가한 화면 3개 (이메일 로그인 2 + 취향 설정 1)
  ├── 01_AUTH/07_email_login.svg
  ├── 01_AUTH/08_email_login_error.svg
  ├── 07_MY/02_preference_settings.svg
  └── PREVIEWS/added_3_screens.jpg
docs/                             ← 이 문서들
```

## 이전 문서와의 관계

- 앞서 만든 `DEVELOPMENT_DIRECTION.md`, `UI_SCREEN_SPEC.md`는 **이 docs/ 폴더로 대체**된다. 충돌 시 docs/가 우선.
- 원본 ChatGPT 개발 방향 문서에서 이어받은 원칙(서버 Source of Truth, DTO/Domain 분리, 상태 UI 필수 등)은 02·03·06에 흡수되어 있다.
- **API 명세와 이 문서가 충돌하면** 임의로 한쪽을 택하지 말고 충돌 지점을 명시해 보고한다.
