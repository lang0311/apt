# CLAUDE.md — APT (졸업 프로젝트) Flutter 앱

이 파일은 Claude Code가 **매 세션 시작 시 읽는 요약**이다. 상세 내용은 `docs/`에 있고, 아래 "언제 무엇을 읽나"에 따라 **필요할 때 해당 문서만** 읽는다. (전부 한 번에 읽지 않는다.)

## 프로젝트 한 줄
인스타그램 릴스 등에서 **"공유"로 장소를 앱에 보내 → 자동 추출·저장 → 저장 장소로 AI가 코스(파티 취향 반영)를 만들어 주는** 앱. 카피: "가고 싶은 곳을, 하나의 코스로."

## 역할과 전제 (절대 어기지 말 것)
1. 클라이언트는 **Flutter** (iOS/Android). 이 레포는 **앱만** 다룬다.
2. 백엔드/API/AI는 **외부에서 제공**된다. 앱은 API 소비자다. 서버·DB를 만들거나 **API 필드/enum/상태값을 추측해서 만들지 않는다.**
   - API 명세가 없으면 `Repository interface + Mock Repository`로 분리하고 해당 부분에 `// NEEDS BACKEND:` 주석을 남긴다. Widget 안에 mock JSON을 넣지 않는다.
   - 또한 API가 없는 상태에서 개발이 진행되는 경우 API를 가용 가능할때 이식하기 편리하도록 이를 고려하여 개발한다.
3. 장소 추출, LLM 추천("트렌디한 곳"), 그룹 취향 집계는 **서버 책임**. 앱은 입력을 정확히 전달하고 결과(추천 이유 포함)를 표시한다.
   - 이 프로젝트의 메인 업무는 프론트앤드 개발로 별도 언급이 없는경우 AI및 서버 관련 작업은 플러터에서 진행하지 않는다.
4. **기존 코드/구조가 있으면 그것을 우선**한다. 무시하고 새로 쓰지 않는다. 순서: Inspect → Understand → Compare → Plan → Implement → Test.
5. 기능 범위가 애매하면 구현 전에 사용자에게 **한 번에 모아서** 묻는다. `docs/07_DECISIONS_AND_OPEN_ITEMS.md`에 이미 정해진 건 다시 묻지 않는다.

## 확정된 결정 (요약)
- UI 기준: `design/ui/canonical_user_flow_ui_svgs`(31화면) + `design/ui/ui_additions`(3화면) = **34화면**. 흐름도 `PREVIEWS/canonical_user_flow.jpg`, `canonical_ui_31_screens.jpg`를 **먼저 보고** 해당 SVG를 연다.
- 로그인: **소셜(카카오/Google/Apple)이 기본**. 이메일 로그인은 **틀만** (`FeatureFlags.emailAuthEnabled=false`, 화면에 진입점 노출 금지, 예외는 간단히).
- 지도: **네이버 지도** (`© NAVER` 표기 유지).
- 주 진입 경로는 **릴스 → 공유 → 우리 앱**(Android `ACTION_SEND`, iOS Share Extension). 앱 내 링크 입력 화면은 URL을 알 때 쓰는 **폴백**.
- 코스 만들기: 정보 → 장소 → 동행 → AI 추천 → (장소 수정 ↔ AI 재추천 **반복 가능**). 위저드는 하나의 `CourseDraft`를 공유, 진행 바는 4/4 유지(새 단계 만들지 않음).
- 저장 구조는 **카테고리(유형별, 서버 데이터) + 보관함(목적별, 사용자 생성)** 두 축. 한 장소는 여러 보관함에 속할 수 있다 (Place ≠ SavedPlace).
- 하단 탭 5개: **홈 · 코스 · 저장됨 · 추출 · 마이**. 활성 표시는 현재 **라우트 기준**.
- 파티 코스 목록은 코스 목록의 "모임/파티 코스" 탭에 통합되어 있다.

## 언제 무엇을 읽나
| 하려는 일 | 읽을 문서 |
|-----------|-----------|
| 처음 / 서비스 의도 확인 | `docs/01_PROJECT_PURPOSE.md` |
| 코드 작성 전, 구조·인증·공유 수신·지도·코스 루프 | `docs/02_APP_DEVELOPMENT.md` |
| UI 구현, 토큰, 컴포넌트, 새 화면 디자인 | `docs/03_DESIGN_SYSTEM.md` |
| 화면 연결, 네비게이션, 사용자 흐름 | `docs/04_UX_FLOWS.md` |
| **특정 화면 구현** (라우트·UI·데이터·상태) | `docs/05_SCREEN_SPEC.md` + 해당 SVG |
| API 연동, Mock, 백엔드에 요청할 것 | `docs/06_API_INTEGRATION.md` |
| 막혔을 때, 정해진 것/가정/미해결 확인 | `docs/07_DECISIONS_AND_OPEN_ITEMS.md` |
| 문서 인덱스 | `docs/README.md` |
문서와 API 명세가 **충돌하면 임의로 한쪽을 택하지 말고** 충돌 지점을 명시해 보고한다. 문서끼리 충돌하면 번호가 큰 쪽(최신 결정은 07)을 확인한다.

## 작업 시작 절차 (코드 수정 전)
1. 레포 트리, Flutter/Dart 버전, `pubspec.yaml` 확인
2. 기존 화면/라우터/상태관리/API 클라이언트/모델/에셋 확인
3. API 명세 확인 (없으면 `NEEDS BACKEND`)
4. 현재 구현과 docs의 차이를 `IMPLEMENTED / PARTIAL / NOT IMPLEMENTED / NEEDS BACKEND`로 분류해 보고
5. 구현 범위를 사용자와 확인 후 작업

## 구현 규칙
**구조**: feature-first (`lib/app`, `lib/core`, `lib/features/{auth,home,extraction,saved,place,course,party,preference,my}`). 과한 Clean Architecture 금지. 상세 구조는 02 문서.
**데이터 흐름**: `DTO → mapper → Domain Model → Provider/Controller → Widget`. Widget에서 JSON/DTO 직접 참조 금지.
**상태**: 서버 연동 화면은 `loading / success / empty / error / refreshing` 모두 처리. 상태관리는 기존 방식 우선(신규면 Riverpod `AsyncValue` 권장).
**하드코딩 금지**: 카테고리, 취향 항목, 통계, 보관함, 추천 비율(카페 42% 등)은 서버 값을 표시. 프론트에서 전체 목록을 받아 count하지 않는다. 시안의 문구/숫자는 예시다.
**D-day**는 날짜에서 계산한다(값으로 가정하지 않음).

## 디자인 구현 규칙
- SVG는 **참고 시안**. 화면 전체를 SVG로 넣지 않고 **Flutter Widget으로 재구현**한다. 지도/사진은 더미 → 실제 지도/이미지로 대체.
- 시안에 글자 기호로 그려진 아이콘(`↝ ⌂ ⌗ ▱ ○ ✓ ! ✦ ≡ ⋮`)은 **실제 아이콘**으로 교체.
- 프레임 390×844는 **참고 기준일 뿐**. **폭을 하드코딩하지 않는다**(390/350/342 금지). 좌우 여백 20(일부 24) + 콘텐츠는 늘어나게. 세로는 스크롤 + 하단 고정 CTA. 360×640 / 390×844 / 430×932에서 확인.
- 가짜 상태바(9:41)·홈 인디케이터는 구현하지 않는다 → `SafeArea`/`MediaQuery.padding`. 키보드 올라올 때 CTA 가려지지 않게 `viewInsets` 처리.
- 시안의 8.5–10px 글자는 구현 시 **본문/설명 11–12sp, 캡션 10–11sp 이상**으로 올린다.
- 토큰 먼저: `AppColors / AppTypography / AppSpacing / AppRadius`. 화면마다 임의 값 금지. 주요 값: primary `#246BFD`, 배경 `#F6F8FC`, 텍스트 `#132238`/`#7B8AA3`, **AI 추천 전용 주황 `#F39A45`(+✦)**, 오류 `#F0645A`. 폰트 Noto Sans KR.
- **AI 추천 장소는 선택 장소와 시각적으로 구분**(주황 ✦ + 추천 이유 라벨). 점수(score)를 그대로 노출하지 않는다.
- 새 화면 전에 **기존 공통 컴포넌트를 검색해 재사용/확장**. 같은 UI를 페이지 안에서 반복 작성하지 않는다.
- 새 화면을 디자인해야 하면 03 문서 §7 원칙(기존 디자인 언어 유지, 해요체)을 따른다.

## 공유(Share) 수신 주의
- 공유 URL이 오면 로그인 상태에서는 **링크 입력을 건너뛰고** 결과 화면에서 분석을 자동 시작. 비로그인이면 `pendingShare`로 보관했다가 로그인 후 재개.
- Instagram 공유 시트에 우리 앱이 실제로 노출되는지는 **실기기 검증이 필요**하다(코드만으로 확정 불가). 수신 패키지는 유지보수/호환성 확인 후 채택.
- 디자인 없는 상태(추출 진행/실패/비공개/장소 없음)는 공통 Loading/Empty/Error 컴포넌트로 임시 구현하고 **사용자에게 알린다.**

## 하지 말 것
- 서버/DB 구현, API 필드·enum 추측
- SVG를 화면 통째로 삽입, 고정 폭 하드코딩
- 카테고리·취향·통계 하드코딩, Widget 안 mock JSON
- 이메일 로그인을 노출 상태로 두기
- 홈을 지도 앱처럼 만들기
- 기존 구조를 무시한 재작성
- 사용자 요청 없이 큰 의존성 추가·구조 변경 (추가 시 이유 설명)

## 개발 단계 (제안, 상세는 02 §10)
1 골격(토큰·라우터·API 클라이언트·공통 컴포넌트·Mock·FeatureFlags) → 2 AUTH → 3 저장됨+장소 상세+네이버 지도 → 4 추출(공유 수신) → 5 홈 → 6 코스 목록+위저드 1–3 → 7 파티·초대+AI 추천 루프·완료·상세 → 8 마이+취향 → 9 폴리시

## 작업 마무리 시
- 변경한 것 / 남은 것 / `NEEDS BACKEND` 항목을 짧게 보고한다.
- 화면 구현 후 **시안 대비 차이**(의도적으로 바꾼 것 포함)를 알린다.
- 새로 확정된 결정이나 가정은 `docs/07_DECISIONS_AND_OPEN_ITEMS.md`에 반영하자고 제안한다.

## 레포 배치 (권장)
```
<repo>/
├── CLAUDE.md
├── docs/                               ← 이 문서들
├── design/
│   └── ui/
│       ├── canonical_user_flow_ui_svgs/    ← 31화면 + PREVIEWS
│       └── ui_additions/                   ← 추가 3화면
└── (Flutter 프로젝트: lib/, pubspec.yaml, android/, ios/ …)
```
위 위치가 다르면 이 파일의 경로를 실제 위치에 맞게 고친다.
