# 03. 디자인 시스템 · 프레임 정책

## 1. 디자인 프레임 (390×844)은 개발에서 문제가 되는가?

**아니다. 큰 문제 아님.**

- Flutter는 논리 픽셀(dp) 기반이고 실제 기기 폭은 대략 **360–430dp**로 다양하다. 390×844는 "디자인 시안의 기준 크기"일 뿐 개발 제약이 아니다.
- 이전에 쓰던 393×852와의 차이(3×8dp)는 레이아웃에 실질 영향이 없다. **31+3개 화면이 전부 390×844로 통일**되어 있다는 점(비율 일관성)이 중요하고, 이미 지켜졌다.
- 문제가 되는 것은 크기가 아니라 **구현 방식**이다. 아래 규칙만 지키면 된다.

### 반응형 구현 규칙
| 규칙 | 내용 |
|------|------|
| 폭 하드코딩 금지 | `390`, `350`, `342`를 코드에 넣지 않는다. 좌우 여백 **20**(화면 따라 24) 고정 + 콘텐츠는 `Expanded`/`double.infinity`로 늘어남 (SVG의 350 = 390 − 20×2) |
| 세로는 스크롤 | 높이 844에 맞추지 말고 `Scaffold` + 스크롤 영역 + 하단 고정 CTA 구조. 작은 기기(예: 높이 ~640)에서도 깨지지 않게 |
| 시스템 영역 | SVG의 **가짜 상태바(9:41, 다이내믹 아일랜드)와 홈 인디케이터는 구현하지 않는다.** `SafeArea` / `MediaQuery.padding`으로 실제 인셋 사용 |
| 하단 탭바 | SVG 높이 90은 홈 인디케이터 영역 포함값. 구현은 콘텐츠 높이 약 56–64 + `bottom inset` |
| 하단 고정 CTA | `SafeArea(bottom)` + 키보드 올라올 때 가려지지 않게 `viewInsets` 처리 |
| 가로 카드/칩 | 줄바꿈(`Wrap`)·가로 스크롤 처리. 칩 폭은 텍스트 길이에 따라 자동 (SVG의 고정 폭은 시안일 뿐) |
| 글자 크기 | 시스템 글꼴 배율을 존중하되 상한 클램프(예: 1.3) — 고정 높이 위젯은 텍스트 늘어남을 고려 |
| 검증 | 최소 3종으로 확인: 작은 폰(360×640 근처), 기준(390×844), 큰 폰(430×932) |

### 주의: SVG의 글자 크기가 작다
시안에는 **8.5–10px 텍스트**가 많다(캡션, 안내문). 실기기에서는 읽기 어렵다.
→ 구현 시 **본문/설명 최소 11–12sp, 캡션 최소 10–11sp**로 올리고, 줄어드는 공간은 줄바꿈/여백으로 흡수할 것을 권장 (디자인 확정 시 사용자와 합의).

## 2. 디자인 방향

키워드: `Clean` `Modern` `iOS-like` `Content first` `Map friendly` `Bottom-sheet oriented` `Minimal`
- 한 화면에 정보를 과하게 넣지 않고 **단계로 나눈다.**
- 지도는 기능이지 홈의 중심이 아니다.
- 소비자 서비스 톤: 흰 바탕 + 파랑 주조색 + 굵은 제목과 띠로 나눈 구역(상자 최소화). 코스는 어디서나 번호 점 + 선(노선)으로 보여 주고, 다가오는 코스 연파랑 카드가 화면의 주인공이다 (2026-11-21 리디자인 v2, 07 D64)
- 화면 모양 기준: 리디자인 v2 확정 시안 https://claude.ai/artifact/QXMdV98JKrHNUjpzPrbyTh (36화면), 구현 확인 https://claude.ai/artifact/B9krM6Jca1jrU5MajdEhJ7

## 3. 토큰 (정본은 코드 `lib/app/theme/`, 이 표는 2026-11-21 리디자인 v2 코드 기준, 07 D64)

처음엔 SVG에서 뽑은 근사치였고, 리디자인(07 D15–D37)을 거치며 아래 값으로 정해졌다. 값이 다르면 코드가 맞다.

### 색상
| 토큰 | 값 | 용도 |
|------|-----|------|
| `primary` | `#246BFD` | 주 버튼, 활성 탭/칩, 링크 |
| `primarySoft` | `#EDF3FF` (진한 단계 `primarySoftStrong` `#DCE8FF`) | 연파랑 버튼(`soft`), 선택 배경 |
| `textPrimary` | `#132238` | 제목, 본문 |
| `textSecondary` | `#5F6E86` (2026-10-20 변경, 시안 `#7B8AA3`는 대비 3.50:1로 미달 → 흰 배경 5.17:1) | 설명, 메타 |
| `textHint` | `#98A3B5` | 장식용 아이콘만 (2.55:1이라 글자에는 쓰지 않음). placeholder·미선택 안내 글자는 `textSecondary` (2026-10-20) |
| `textTertiary` | `#6B7890` | 탭 개수·대기 단계처럼 한 단계 낮춰 읽는 보조 글자 (흰 배경 약 4.7:1, 2026-10-21) |
| `ink` | `#14223A` | 다크 버튼(`AppButtonVariant.dark`), 고른 칩 채움, 하단 탭 활성, 내가 고른 곳 번호 원 (v2) |
| `bg` | `#FFFFFF` (2026-11-21 v2, 이전 `#EEF1F5`) | 화면 배경. 구역은 색 대신 `fill` 띠(`SectionGap` 10)로 나눈다 |
| `surface` | `#FFFFFF` (v2) | 시트 · 일정 카드(1px `divider` 선으로 경계) |
| `fill` (= `surfaceMuted`) | `#EEF2F8` | 구역 띠 · 보조 버튼 · 칩 · 입력칸 바탕 · 회색 판 (v2) |
| `surfaceRaised` | `#FFFFFF` | `surface` 카드 **안**에 놓이는 카드 (2026-10-20) |
| `border` | `#E4EAF3` | 입력/칩 테두리 |
| `controlBorder` | `#8B97AB` | 체크박스·라디오 **미선택 테두리**(두께 1.6, 흰 배경 약 3:1). 고를 수 없는 항목은 `border` 유지 (2026-10-20) |
| `divider` | `#E9EEF5` | 구분선 (비활성 진행 바는 `progressInactive` `#DCE4F0`) |
| `ai` | `#F39A45` (배경 `#FFF1E4`) | **AI 추천 전용 강조** (✦, 주황 핀/뱃지, 'AI 추천' 태그·라벨) |
| `aiText` | `#A85400` | 주황 글자로 읽어야 하는 AI 표시 (흰 배경 5.34:1) — 장소 시트의 ✦ 아이콘 · 저장됨의 `○○ 코스에서 추천`. `ai`는 글자 대비 2.21:1이라 글자에는 쓰지 않는다. 추천 이유 문장은 본문 글씨를 쓴다(07 D40) (2026-10-20) |
| `danger` | `#F0645A` | 오류, 로그아웃 |
| `dangerText` | `#C8463C` | 차단·삭제 같은 위험 동작의 **글자** (흰 배경 약 5:1, 2026-10-21). 시트에서는 구분선 아래 따로 떼어 두고 아이콘과 함께 쓴다 |
| `success` | `#16A07D` | 완료 |
| `extract` | `#8A63E6` | 추출 계열 보조(보라) |
| `kakao` | `#FEE500` | 카카오 버튼 (아이콘은 카카오 로그인 버튼 리소스의 공식 말풍선 심볼 `KakaoSymbol`, 검정 `#000000`. 로그인 · 공유 모두) |
| (Google) | 흰 원 + `border` 1px | Google 간편 로그인 동그라미. 아이콘은 Google 로그인 버튼 리소스의 공식 4색 G `GoogleMark`(빨 `#EA4335` · 파 `#4285F4` · 노 `#FBBC05` · 초 `#34A853`, 색 · 모양 변경 금지) |

> `ai` 색은 **AI가 추천한 것에만** 쓴다 (선택 장소와의 시각적 구분이 핵심).

### 타이포 (IBM Plex Sans KR, `AppTypography`, 2026-11-21 v2)
크기는 네 단계 — 제목 26 · 섹션 18 · 본문 15 · 보조 13(캡션 12 이상). 기존 이름은 남기고 값만 이 체계로 맞췄다.

| 토큰 | 크기 / 두께 | 용도 |
|------|-------------|------|
| `display` | 26 / 700 | 화면 큰 제목(가입 · 초대 수락 · 내 취향 · 추천하지 않는 장소) |
| `hero` · `title` | 24 / 700 | 코스 이름 · 장소 상세 이름 · 마이 숫자 · 위저드 질문 |
| `section` | 18 / 700 | 섹션 제목(`SectionCard`) |
| `header` | 17 / 600 | 뒤로 가기가 있는 화면의 머리 제목(`PlainHeader`) |
| `cardTitle` | 16 / 700 | 카드 · 판 제목, 작은 섹션 제목 |
| `button` | 16 / 600 | 버튼 |
| `bodyStrong` | 15 / 600 | 행 이름 |
| `body` · `bodyMuted` | 15 / 400 (잉크 · `textSecondary`) | 본문 · 설명 |
| `label` | 13 / 600 | 입력 · 그룹 라벨 |
| `meta` | 13 / 400 (`textTertiary`) | 메타 한 줄 |
| `caption` | 12 / 400 (`textTertiary`) | 캡션 |

숫자 칸(마이 숫자 · D-day · n곳)은 `FontFeature.tabularFigures()`로 자릿수 폭을 맞춘다.

화면에서 `copyWith(fontSize:)`로 크기를 바꾸지 않는다. 색 · 굵기만 바꾼다(07 D63).

지도 · 사진 위에 얹는 색도 토큰으로 쓴다(07 D63): 지도 위 흐린 바탕 `mapGlass`(흰색 85%) + 테두리 `mapGlassBorder`(90%), 지도 위 알약 `mapPill`(94%), 사진 위 둘째 줄 글자 `onPhotoMuted`(88%), 안 고른 칩 글자 `chipText`, 파티원 얼굴 · 이름 색 `avatar…`.

### 형태
| 요소 | 값 |
|------|-----|
| 좌우 여백 | 20 (`AppSpacing.screenH`, 일부 24) |
| 입력 필드 | 높이 52(칸 안 이름표가 있으면 58), radius 14, `fill` 바탕 · 테두리 없음, 포커스 2px `primary` · 오류 2px `danger` + 아래 `dangerText` 한 줄 (v2) |
| 주 버튼 | `AppButton` 높이 54 · 작은 버튼 40(`AppSpacing.smallButtonHeight`), radius 14. 보조(`white` · `secondary`)는 `fill` 바탕 + 잉크 글자, 테두리 없음(v2). 나머지 규칙은 07 D57 |
| 하단 고정 버튼 | `BottomCta`: 바탕 `bg`, 여백 위 12 · 좌우 20 · 아래 16(SafeArea 포함) |
| 카드 | v2에서는 상자를 거의 쓰지 않는다. 묶어야 하면 흰 바탕 + 1px `divider` 선 radius 20(일정 카드) 또는 `fill` 회색 판 radius 16~18 |
| 섹션 묶음 | `SectionCard`: 테두리 · 바탕 없이 굵은 제목 18 + 내용, 바깥 4 + 안쪽 16 = 글자 왼쪽 20. 구역 사이는 `SectionGap`(채움 띠 10). 행 사이 선 없음 (v2) |
| 칩 | 높이 36 알약, 기본 `fill` 바탕 / 고른 칩 = `ink` 채움 + 흰 글자 (v2) |
| 모서리 | 네 단계(07 D56): 작게 10(썸네일 · 아이콘 칸 · 태그) · 중간 14(입력칸 · 버튼 · 사진 · 카드 안 타일) · 크게 20(카드) · 시트 28 · 알약 999 (`AppRadius.small · medium · large · sheet · pill`). 그보다 작은 태그 · 모자이크 칸 · 체크박스는 `AppRadius.tiny` 6(07 D63), 진행 막대 · 손잡이(2~3)만 숫자를 그대로 쓴다 |
| 뒤로가기 버튼 | **배경 없는 아이콘**(`PlainHeader`, 누르는 영역 48, 제목 17): 코스 화면 · 보관함 상세. 가입 화면은 `AuthHeader`(큰 제목 위 아이콘), 장소 상세는 사진 위 흰 원 버튼 — 2026-10-21, 10-30 07 D37 |
| 진행 바 | 4분할, 높이 4, radius 2, 활성 primary / 비활성 `divider` |
| 바텀시트 | 상단 radius 28 + 핸들 |
| 하단 탭 | 5개 (홈 · 저장됨 · 코스 · 장소 추가 · 마이) 같은 크기, 가운데 띄운 버튼 없음, 활성 = 잉크 + 굵은 선 (v2, 07 D64) |
| 간격 스케일 | 4 · 8 · 12 · 16 · 20 · 24 · 32 |

`AppColors / AppTypography / AppSpacing / AppRadius / AppShadow`로 먼저 토큰화하고, 화면마다 임의 값을 만들지 않는다.

## 4. 공통 컴포넌트

2026-11-21 코드(`lib/core/widgets/`, 각 기능의 `presentation/widgets/`) 기준 이름이다. 리디자인 v2(07 D64)에서 바뀐 것을 반영했다.

**기본 (`core/widgets`)**: `AppButton`(`primary`·`dark`·`soft`·`white`·`danger`) `AppTextLink` `AppIconBox` `AppTextField`(채움 바탕, 칸 안 이름표 `innerLabel`, 오류 2px) `AppFieldError` `AppSearchField` `AppChip` `AppTextChip` `ChipScroller` `AppTag` `TagWrap` `CheckMark`(체크 아이콘만, 07 D26) `NumberBadge` `SegmentedTabs`(track / pills / underline) `AppLogo` `StationSteps`(번호 정거장을 선으로 이은 세로 단계 — 가입 완료 · 장소 추가 안내, v2)
**브랜드 로고 (`core/widgets/brand_marks.dart`)**: `KakaoSymbol`(카카오 공식 말풍선, 18×18 패스) `GoogleMark`(Google 공식 4색 G, 48×48 패스). 각 사 로그인 버튼 리소스의 패스를 `CustomPaint`로 그대로 옮겼다(패키지 없음). 색 · 비율을 바꾸지 않는다
**헤더**: `PageTitleHeader`(탭 화면 큰 제목) `PlainHeader`(배경 없는 뒤로 + 제목) `AuthHeader`(가입 화면) `StepHeader`(위저드 뒤로 + 제목 + n/4) `StepProgressBar`(막대 아래 단계 이름 `정보 · 동행 · 장소 · 추천`, 지금 단계만 파랑 · 굵게) `SectionHeader`
**표면 · 하단**: `SectionCard`(v2: 상자 없이 굵은 제목 18 + 내용, 제목 줄 오른쪽 `trailing`. 일정 카드만 `boxed: true` — 흰 바탕 + 1px 선 모서리 20) `SectionGap`(구역 사이 채움 띠 10) `DividedRows`(행 목록, v2에서는 선 없이 여백만) `AppCard` `IconCircle` `BottomCta`(하단 고정 버튼 영역)
**오버레이**: `showAppSnackBar`(하단 고정 버튼이 있으면 그 위 8에 뜸, 07 D36) `showAppBottomSheet` `showAppModal` `showConfirmDialog` `showActionSheet`
**상태**: `AsyncValueView`(로딩 · 빈 · 오류를 한 번에) `AppLoading` `SkeletonBox` `SkeletonList` `AppEmptyState` `AppErrorState`
**사진 · 장소**: `PlaceImage`(사진 없으면 카테고리 색 칸 + 아이콘, 같은 크기 유지. 아이콘 색은 `CategoryStyle.ink` — 음식점 · 전시는 바탕과 3:1이 되게 진한 값, 07 D56) `AppNetworkImage` `PlaceListTile` `SavedPlaceRow` `CollectionRow`(2×2 `MiniCollage`, 시트용) `CollectionGrid` · `CollectionGridCard`(보관함 탭 2열 정사각 표지, v2) `AllPlacesLink` `ExtractedPlaceRow` `RatingText` `AppliedFilterChip`(걸린 필터, 남색 — 건 값만 하나씩) `showCategoryFilterSheet`(여러 개 고르는 카테고리 시트. `sources`를 주면 제목 `필터` + `보여 줄 장소`(직접 저장 · 추천받은 곳), `autoSearch`를 주면 `지도 이동 시 자동 검색` 스위치, 이때 버튼은 `적용`) `HeaderTextButton`
**홈**: `HomeCourseCard`(v2 연파랑 판, D-day · 노선 점만 파랑. D-day + 옆에 날짜 · 출발 · 이름 + 오른쪽 거리 · 인원 · 장소 순서 줄 — 선으로 이은 28 업종 동그라미 + 이름 두 줄, 5곳까지 모두, 6곳부터 앞 셋 · `+n` · 마지막, AI 동그라미에 작은 ✦) `HomeRegionGroups`(지역별로 시작하기 — 구 · 시 묶음 세 개, 모자이크 + `코스 만들기`) `HomeQuickActions` `HomeStartGuide` `NewSavesNudge` `RecentSavedStrip` `SuggestedCourseStrip` `TrendingPlaceGrid`
**지도**: `AptMap`(네이버 · 웹 타일 · 미리보기 지도를 감쌈) `MapPin`(번호/선택/AI/내 위치/`picked` 파란 체크 — 3단계에서 고른 곳, 순서 번호 없음) `MapPlacePicker`(지도 위 장소 고르기, 3단계 · 장소 추가 공용. 카드 · 목록은 지금 지도 영역 안의 장소만, 목록은 아래에서 올라오는 시트) `CourseRouteMap`
**코스**: `CourseHero`(이름 + 한 줄 정보, 요약 칸을 쓰는 화면은 정보 줄 없음) `CourseStats`(날짜 · 출발 · 직선 거리, 있는 칸만) `CourseStopLegend`(`내가 고른 곳 n · AI 추천 n`) `CourseThumb`(사진 없으면 업종 모자이크: 1곳 한 칸 · 2곳 반반 · 3곳 큰 칸 + 둘 · 4곳 2×2 · 5곳부터 셋 + `+n`) `CourseDayChips`(오늘부터 2주 날짜 칩 + 달력) `showCourseTimeSheet`(출발 시간 휠) `CourseTimeline`(보기, 마커 사이를 한 줄로 이음) `CourseEditList`(편집) `CourseEditButton` `StopMarker`(번호, AI 추천은 주황 번호 + 작은 ✦ — 번호는 AI 곳까지 이어짐, 07 D62) `CourseSummaryRow` `PickedChips`(고른 장소 칩 줄, ×로 빼기) `RecommendingBanner`(추천 진행 · 취소) 장소 시트(`StopSheetAction`, 차단은 빨간 글자로 떼어 둠)
**파티 · 공유 · 인증**: `PartyAvatarStack` `ShareOption`(초대 · 코스 알리기 시트 공통) `SocialLoginButton` `SocialIconButton`
규칙: 페이지 안에서 같은 UI를 반복 작성하지 않는다. 새 화면 전에 **기존 컴포넌트를 검색해 재사용/확장**한다.

## 5. 아이콘 · SVG 사용 원칙

- SVG는 **참고 시안**이다. 화면 전체를 SVG로 넣지 않는다. 일러스트/로고/핀 같은 **자산 용도**로만 사용.
- 시안에 글자 기호로 그려진 아이콘(`↝ ⌂ ⌗ ▱ ○`, `✓ ! ✦ ≡ ⋮`)은 **실제 아이콘 세트**(Material Symbols 등)로 교체.
- 이동 수단(도보/버스/대중교통)도 아이콘 위젯 + 텍스트.
- SVG 속 사진/지도는 더미 → 실제 이미지 위젯/네이버 지도로 대체.
- 이미지 모서리는 `ClipRRect`.
- 브랜드 로고(카카오 · Google)는 비슷하게 그리지 않고 각 사 공식 리소스의 모양 · 색 그대로 쓴다(`brand_marks.dart`).

## 6. 반드시 구현할 UI 상태

`Loading` `Empty` `Error` `Disabled` `Selected` `Saved` `AI Recommended` `Pressed`
- 모든 목록: 로딩 스켈레톤 · 빈 상태(행동 유도 문구 + CTA) · 오류(재시도)
- 폼: 기본 · 포커스 · 오류(인라인) · 비활성 버튼

## 7. 새 화면을 디자인할 때의 원칙 (디자인 언어 유지)

처음엔 추가 화면 3개(07, 08, 34)의 규칙이었고, 5개 탭(10-22) · 탭 밖 화면(10-30, 07 D37) 리디자인을 거쳐 2026-11-21 리디자인 v2(07 D64)로 아래처럼 정리됐다. 모든 화면이 이 언어를 따른다.

1. 바탕은 흰색, 구역은 굵은 제목 + `fill` 띠로 나눈다. 상자 · 그림자를 쓰지 않고, 묶어야 할 때만 회색 판 또는 1px 선 카드 (2026-11-21 v2, 07 D64)
2. 서브 화면 헤더 = **배경 없는 뒤로 아이콘 + 제목**(`PlainHeader`, 위저드는 `StepHeader` 우측 `n/4`). 흰 사각 뒤로 버튼(`SubPageHeader`)은 없앴다 (07 D37)
3. 인증/설정류 첫 화면은 **큰 제목(`display` 26/700) + 설명 + 입력들**, 주 버튼은 **`BottomCta`로 하단 고정**(키보드가 올라와도 가리지 않게)
4. 관련 항목은 `SectionCard` 제목 아래 화면 끝까지 가는 행(좌우 20, 선 없음)으로 둔다. 선택형 항목은 높이 36 알약 칩, 라디오 · 체크는 `CheckMark`
5. 오류는 **빨강 테두리 + 아이콘 + 한 줄 메시지** (큰 별도 화면은 정말 필요한 때만). 상황 설명은 제목으로 올리고 장식용 `!` 원 카드는 쓰지 않는다 (07 D37)
6. 꾸미는 아이콘 원 · 일러스트를 넣지 않는다. 안내는 문장과 행동 버튼으로 (07 D37)
7. ✦ · 주황(`ai`)은 **AI가 추천한 장소 표시로만** 쓴다(주황 번호 원 · 작은 ✦ · `AI 추천` 태그 · 시트의 추천 이유 줄 아이콘 · 저장됨의 `코스에서 추천`). 제목 · 배경 · 버튼 장식 금지 (07 D17)
8. 하단 탭 화면(홈·저장됨·코스·장소 추가·마이) 헤더는 **큰 제목 + 오른쪽 버튼만** 둔다. 정보 없는 분위기 부제는 쓰지 않는다 (2026-10-20, 07 D16)
9. 강조는 카드마다 한 곳만(예: 코스 카드는 D-day만 크게). 숫자 통계 타일은 쓰지 않는다 (2026-10-20, 07 D20)
10. 문구는 해요체, 짧고 행동 중심 ("~해주세요", "~할 수 있어요")
