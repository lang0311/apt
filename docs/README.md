# APT 프로젝트 문서 목차

> 이 폴더의 목차다. **작업 규칙은 `CLAUDE.md`, 최신 결정은 `07`** 을 본다. 문서는 필요할 때 해당 문서만 읽는다.
> 클라이언트: Flutter · 백엔드/AI: 외부 제공(API 소비자) · 갱신: 2026-11-21 (리디자인 v2)

## 문서 구성

| 파일 | 주제 | 언제 읽나 |
|------|------|-----------|
| [01_PROJECT_PURPOSE.md](01_PROJECT_PURPOSE.md) | 서비스 목적 · 핵심 가치 · 책임 분담 | 처음 / 서비스 의도 확인 |
| [02_APP_DEVELOPMENT.md](02_APP_DEVELOPMENT.md) | Flutter 앱 개발: 아키텍처 · 인증 · 공유 수신 · 지도 · 개발 단계 · 작업 규칙 | 코드 작성 전 |
| [03_DESIGN_SYSTEM.md](03_DESIGN_SYSTEM.md) | 디자인 프레임 정책 · 토큰 · 컴포넌트 · 새 화면 디자인 원칙 | UI 구현/신규 디자인 시 |
| [04_UX_FLOWS.md](04_UX_FLOWS.md) | 사용자 흐름: 인증 · 공유 추출 · 저장 · 코스 루프 · 파티 · 취향 | 화면 연결/네비게이션 구현 시 |
| [05_SCREEN_SPEC.md](05_SCREEN_SPEC.md) | 화면 명세 (라우트 · UI · 데이터 · 상태), 맨 앞에 리디자인 v2 요약 표 | 화면 단위 구현 시 |
| [06_API_INTEGRATION.md](06_API_INTEGRATION.md) | 백엔드 연동 원칙 · 필요 데이터 목록 · Mock 전략 | API 연동/백엔드 협의 시 |
| [../README.md](../README.md) | **실행 방법**: 준비물 · 키 파일 · Mock / 서버 연결(에뮬레이터 · 웹 · `run.cmd`) · Mock 확인 규칙 · 테스트 · 자주 막히는 것 | 처음 받아서 실행할 때 |
| [LOCAL_BACKEND.md](LOCAL_BACKEND.md) | 팀 Python 서버에 붙여 실행하기(웹 · Android), 연결된 기능 · 미연동 기능 | 서버 모드로 실행 · 시연할 때 |
| [API/](API/) | 엑셀 API 초안 (응답 형식 없음, 서버와 작성자 다름) — **서버에 없는 기능만 참고**. 백엔드 기준은 팀 서버 코드(06 §0) | API 연동/백엔드 협의 시 |
| [07_DECISIONS_AND_OPEN_ITEMS.md](07_DECISIONS_AND_OPEN_ITEMS.md) | 확정 결정(D1–) · 가정 · 미해결 항목 | 막혔을 때 / 범위 확인 시 |
| `08_DEV_LOG.docx` | 개발 일지 (생성: `tools/devlog`) — **개인 레포에만 있음** | 진행 상황 공유 / 보고 시 |
| `09_COMMIT_CONVENTION.md` | 커밋 규칙 · 키 검사 · 팀 레포 반영 — **개인 레포 작업 규칙, 개인 레포에만 있음** | 커밋 전 |
| `10_MY_WORKFLOW.md` | 작업 방식 · 시안 없이 해도 되는 경우 · 완료 기준 · 개발 일지 기준 — **개인 레포 작업 규칙, 개인 레포에만 있음** | 매 세션 |

확정 사항은 이 파일에 따로 적지 않는다. 요약은 `CLAUDE.md` "확정된 결정", 전체는 `07` §1 표가 정본이다.

## 자료 위치

```
리디자인 v2 확정 시안 (화면 모양 기준)   ← https://claude.ai/artifact/QXMdV98JKrHNUjpzPrbyTh (36화면)
구현 vs 시안 확인 페이지                 ← https://claude.ai/artifact/B9krM6Jca1jrU5MajdEhJ7 (2026-11-21 캡처)
design/ui/canonical_user_flow_ui_svgs/   ← 처음 기준 31개 화면 + 흐름도 (화면 번호 · 흐름 출처)
design/ui/ui_additions/                  ← 추가 3개 화면 (이메일 로그인 2 + 취향 설정 1)
docs/screenshots/                        ← 리디자인 캡처·시안 로컬 사본 (gitignore, 레포에 없음)
docs/_archive/                           ← 이전 문서 (DEVELOPMENT_DIRECTION.md, UI_SCREEN_SPEC.md) — 참고용
```

- 2026-11-21 **리디자인 v2**(07 D64)로 모든 화면이 SVG와 다르다(흰 바탕 · 띠 구분 · IBM Plex Sans KR · 하단 탭 다섯 칸 같게). 화면 모양은 v2 시안과 `03` · `05`를 본다. 그 전 리디자인 기록은 `07` D15–D27 · D37 · D40–D63.
- **API 명세와 문서가 충돌하면** 임의로 한쪽을 택하지 말고 충돌 지점을 명시해 보고한다.
