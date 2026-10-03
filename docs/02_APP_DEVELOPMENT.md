# 02. 앱 개발 가이드 (Flutter)

## 1. 전제

- 클라이언트는 **Flutter** (iOS / Android 단일 코드베이스).
- 백엔드/API/AI는 **제공받는다.** 앱은 API 소비자 → 서버 구조를 만들거나 추측하지 않는다.
- UI 기준은 `canonical_user_flow_ui_svgs`(31) + `ui_additions`(3) = **34개 화면**.
- 기존 Flutter 레포가 있으면 **그 구조를 우선**한다. 아래 구조는 레포가 없을 때의 제안이다.

## 2. 작업 시작 절차 (코드 수정 전)

1. repository tree, Flutter/Dart 버전, `pubspec.yaml` 확인
2. 기존 화면 / 라우터 / 상태관리 / API 클라이언트 / 모델 / 에셋 확인
3. API 명세(또는 DTO/문서) 확인 — 없으면 `NEEDS BACKEND`
4. 이 docs와의 차이 분석 후 보고 (아래 형식)
5. 구현 범위를 사용자와 확인한 뒤 작업

**보고 형식**
```
## Current Architecture / Existing Screens / Models / APIs / Assets / State / Navigation
## Gap Against docs
### IMPLEMENTED / PARTIAL / NOT IMPLEMENTED / NEEDS BACKEND
```

원칙: `Inspect → Understand → Compare → Plan → Implement → Test`. 기존 코드를 무시하고 새로 쓰지 않는다.

## 3. 아키텍처 (제안)

```
lib/
├── app/            app.dart, router.dart, theme/ (tokens), di/
├── core/           network/ (api client, interceptors), error/, storage/, utils/, widgets/ (공통 컴포넌트)
└── features/
    ├── auth/           social + email(stub), terms, profile, conflict/error
    ├── home/
    ├── extraction/     링크 입력, 결과 검토, 보관함 선택, 공유 수신
    ├── saved/          카테고리, 보관함, 보관함 상세, 저장 지도
    ├── place/          장소 상세
    ├── course/         목록, 위저드(CourseDraft), AI 추천 루프, 상세/관리
    ├── party/          초대, 수락, 파티원
    ├── preference/     취향 설정
    └── my/
```

Feature 내부: `data/(datasource, dto, repository)` · `domain/(model, repository)` · `presentation/(page, widget, provider)`
졸업프로젝트 규모에 과한 Clean Architecture는 피한다. 목표는 **파일 수가 아니라 분리**다.

**데이터 흐름**: `API Response(DTO) → mapper → Domain Model → Provider/Controller → Widget`
- Widget에서 JSON/DTO를 직접 참조하지 않는다 (`Text(place.name)` ✅, `Text(json['place']['name'])` ❌).
- 상태관리는 **기존 프로젝트 방식 우선**, 신규면 Riverpod 등 `AsyncValue` 기반을 권장.
- 모든 서버 연동 화면은 `loading / success / empty / error / refreshing`을 처리한다.

## 4. 인증 (소셜 중심 + 이메일 틀)

### 4.1 구조
```
AuthRepository (interface)
 ├── SocialAuthProvider  : Kakao / Google / Apple   ← 실제 구현
 └── EmailAuthProvider   : stub (틀만)               ← feature flag 뒤에 숨김
```
- `FeatureFlags.emailAuthEnabled = false` (기본). 꺼져 있으면 소셜 로그인 화면에 이메일 진입 링크를 **노출하지 않는다.**
- 이메일 로그인 화면(#7)과 오류 화면(#8)은 **UI와 폼 검증, 에러 표시까지만** 구현. 실제 호출은 `EmailAuthProvider`가 `NotImplemented`/Mock으로 응답.
- "비밀번호 찾기", "이메일로 가입하기"는 **라우트만 잡고 TODO 화면**(또는 비활성)으로 둔다. 가입 폼/약관 재사용 여부는 백엔드 정책 확인 후 결정.
- 토큰 저장은 `flutter_secure_storage` 계열 보안 저장소, 만료/갱신 정책은 **API 명세 기준**.

### 4.2 예외 처리 (간단하게)
| 상황 | 처리 |
|------|------|
| 소셜 인증 취소/실패 | 화면 #6 (재시도 / 고객센터) |
| 동일 이메일 기존 계정 | 화면 #5 (연결 / 다른 계정) |
| 이메일 로그인 실패 | 화면 #8 — 필드 인라인 에러 (이메일/비밀번호 둘 다 빨강 + 한 줄 메시지) |
| 네트워크 오류 | 스낵바/토스트 + 재시도 (별도 화면 만들지 않음) |
| 세션 만료 | 로그인 화면으로 이동, **보류 중인 공유 URL은 보존** (§5.3) |

## 5. 공유(Share) 수신 — 핵심 진입 경로

> 서비스의 주 진입은 인스타그램 릴스 `공유 → 우리 앱`이다. 앱 내부 링크 입력(#10)은 **폴백**.

### 5.1 플랫폼별
| 플랫폼 | 방식 |
|--------|------|
| Android | `ACTION_SEND` (`text/plain`) intent-filter 등록, 앱 실행 중/종료 상태 모두 수신 |
| iOS | **Share Extension 타깃** 추가 필요 (Xcode), 앱과 App Group으로 데이터 전달 |
| 공통 | Flutter 쪽 수신 패키지(예: `receive_sharing_intent` 등)는 **유지보수 상태와 호환성을 먼저 확인**하고 채택. 필요 시 플랫폼 채널 직접 구현 |

- Instagram의 공유 메뉴에서 **시스템 공유 시트로 넘어갔을 때 우리 앱이 노출되는지**는 실제 기기(iOS/Android)에서 검증해야 한다. 노출 경로가 막히면 클립보드 감지(`클립보드에서 붙여넣기`)가 대안.
- 수신 대상은 `instagram.com/reel/…`, `/p/…` 형태의 URL. 그 외 텍스트/링크는 안내 후 무시.

### 5.2 앱 내 처리 흐름
```
공유 수신(콜드/웜 스타트 모두) → URL 검증
  ├─ 로그인 상태 → /extract/result 로 진입하며 분석 자동 시작 (링크 입력 화면 건너뜀)
  └─ 비로그인 → pendingShare 저장 → 로그인/가입 완료 후 이어서 진행
분석 중(진행 상태 표시) → 결과 검토 → 보관함 선택 → 저장
```

### 5.3 pendingShare
공유 URL을 받았는데 로그인/약관이 안 끝났다면 **URL을 안전하게 보관**하고, 홈 진입 직후 추출 흐름을 재개한다.
(디자인에 없는 흐름이므로 최소 UI: 홈에서 바로 추출 결과 화면으로 이동 + 토스트.)

### 5.4 디자인에 없어서 필요한 상태
추출 진행 중(단계 메시지) · 잘못된 URL · 비공개/지원 불가 게시물 · 장소 못 찾음 · 추출 실패(재시도) · 저장 완료 피드백.
→ 03_DESIGN_SYSTEM의 EmptyState/ErrorState/Loading 컴포넌트로 **먼저 임시 구현**하고, 필요 시 별도 디자인 요청.

## 6. 지도 — 네이버 지도 (확정)

- SDK: **네이버 지도 Flutter SDK** (예: `flutter_naver_map`). Naver Cloud Platform 앱 등록/클라이언트 ID 발급 필요. **최신 버전·키 설정·이용약관은 공식 문서로 확인**한 뒤 도입.
- 화면 하단 `© NAVER` 표기는 SDK가 기본 제공하는 것을 사용 (임의 제거 금지).
- 지도 사용 화면: 저장 지도(#18, #19), 코스 장소 선택(#24), 장소 추가(#29), AI 추천 동선(#30), 코스 완료 요약(#31), 코스 상세(#32).
- 공통 위젯: `AptMap`(래핑) + `MapPin`(번호/선택/AI 추천 주황 ✦/내 위치) + 드래그 가능한 `MapBottomSheet`.
- 저장 지도는 **viewport(bounding box) 기반 조회 + debounce**, 줌 아웃 시 클러스터링 (서버 지원 여부 확인).
- 경로선은 직선이 아니라 **도로를 따르는 polyline**이 디자인 의도. 경로/이동시간 데이터를 **서버가 주는지, 앱이 지도/길찾기 API를 호출하는지** 확인 필요 (비용·키 노출 문제로 서버 경유 권장).
- 네이버 지도는 **국내 중심**이므로 해외 장소가 들어올 수 있는지 서비스 범위 확인.

## 7. 코스 만들기 루프 구현 메모

```
CourseDraft { name, date, startTime, moods[], places[ {placeId, source: USER|AI, order} ],
              companion: SOLO|PARTY, partyId?, recommendationRound }
정보(1) → 장소(2) → 동행(3) → AI 추천(4) ⇄ [장소 수정 → AI 재추천] → 완료 → 상세
```
- 위저드 전 단계가 **하나의 `CourseDraft`를 공유**하고, 뒤로 가기에도 입력이 유지된다.
- 4단계에서 **장소 교체/삭제/순서 변경 → "다른 추천"을 반복**할 수 있다 (진행 바는 4/4 유지, 새 단계를 만들지 않는다).
- 코스 **완성 후**(#32 코스 상세)에도 `순서 편집 / 장소 추가 / 다른 추천 받기`로 같은 루프에 재진입할 수 있다.
- 각 장소는 `source(USER/AI)`를 가지고 UI에서 구분 (AI 추천 = 주황 ✦ + 이유 라벨).
- 재추천 요청 시 **현재 코스 상태(사용자가 확정한 장소 / 제외한 추천)를 서버에 어떻게 전달할지는 API 명세 기준.** 앱은 `CourseDraft`에 `rejectedPlaceIds` 같은 필드를 가질 수 있게만 설계해 둔다.
- LLM 응답은 느릴 수 있다 → 단계형 로딩, 타임아웃, 재시도, 이전 추천 유지(깜빡임 방지).

## 8. 성능 · 네트워크

- 지도: marker rebuild 최소화, 이동 쿼리 debounce, polyline 캐싱
- 이미지: 캐시 사용(`cached_network_image` 등), 썸네일 우선, 원본 무조건 다운로드 금지
- 목록: 페이지네이션(cursor 제공 시) + lazy loading
- 코스 목록/상세: 카드에 필요한 summary를 API가 한 번에 주도록 요청 (N+1 방지)
- 홈 통계: 서버 aggregate 사용 (전체 목록 받아 count 금지)

## 9. 이벤트 로깅 (서버 지원 시)

추천 품질을 위해 사용자 반응을 서버로 보낼 수 있다면: 장소 저장/해제, 코스 장소 추가/삭제/순서 변경, 추천 수락/거절/재요청, 추출 시작/성공/실패.
이벤트명/스키마는 **서버 명세를 따른다.** 없으면 `NEEDS BACKEND`로 기록.

## 10. 개발 단계 (제안)

| Phase | 내용 | 비고 |
|-------|------|------|
| 1 | 골격: 토큰/테마, 라우터(Shell+탭), API 클라이언트, 공통 컴포넌트, Mock Repository, FeatureFlags | |
| 2 | AUTH: 소셜 로그인/약관/프로필/완료/예외 + 이메일 틀(#7, #8) | 소셜 SDK 키 필요 |
| 3 | 저장됨 + 장소 상세 + 네이버 지도 (#13–#20) | 지도 SDK 연동 |
| 4 | 추출: 공유 수신 → 결과 검토 → 보관함 선택 (#10–#12) + 링크 입력 폴백, pendingShare | iOS Share Extension 포함 |
| 5 | 홈 (#9) | 실데이터 연결 후 |
| 6 | 코스 목록 + 위저드 1–3단계 (#21–#26, #29) | `CourseDraft` |
| 7 | 파티·초대 (#27, #28) + AI 추천 루프·완료·상세 (#30–#32) | LLM 지연 UX |
| 8 | 마이 + 취향 설정 (#33, #34) | 취향 항목은 서버 키워드 |
| 9 | 폴리시: 접근성, 오류/빈 상태 점검, 성능 | |

API가 없는 단계는 **Repository Interface + Mock Repository**로 UI를 먼저 완성하고, 명세 수령 후 실제 연동으로 교체한다. Widget 내부에 mock JSON을 넣지 않는다.

## 11. 하지 말 것

- SVG를 화면 전체에 넣기 / 390 같은 고정 폭 하드코딩
- 카테고리·취향 항목·통계 하드코딩
- API 필드/enum/상태값 **추측해서 만들기**
- 홈을 지도 앱처럼 만들기
- 이메일 로그인을 노출 상태로 출시 (flag off 유지)
- 기존 코드/구조를 무시한 재작성
