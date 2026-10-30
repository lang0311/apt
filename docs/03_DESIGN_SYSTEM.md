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
- 소비자 서비스 톤: 밝은 배경 + 파랑 주조색 + 둥근 카드.

## 3. 토큰 (정본은 코드 `lib/app/theme/`, 이 표는 2026-10-30 코드 기준)

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
| `ink` | `#14223A` | 다크 버튼(`AppButton.dark`), 하단 탭 가운데 코스 버튼 |
| `bg` | `#EEF1F5` (2026-10-20 변경, 시안 `#F6F8FC`는 흰 카드와 거의 구분되지 않음) | 화면 배경, 탭 화면 상단바 |
| `surface` | `#F9FAFC` (2026-10-20 변경, 시안 `#FFFFFF`) | 섹션 묶음·카드·입력·탭바. 카드는 `border` 1px로 경계를 잡는다(그림자 없음) |
| `surfaceRaised` | `#FFFFFF` | `surface` 카드 **안**에 놓이는 카드 (2026-10-20) |
| `border` | `#E4EAF3` | 입력/칩 테두리 |
| `controlBorder` | `#8B97AB` | 체크박스·라디오 **미선택 테두리**(두께 1.6, 흰 배경 약 3:1). 고를 수 없는 항목은 `border` 유지 (2026-10-20) |
| `divider` | `#E9EEF5` | 구분선 (비활성 진행 바는 `progressInactive` `#DCE4F0`) |
| `ai` | `#F39A45` (배경 `#FFF1E4`) | **AI 추천 전용 강조** (✦, 주황 핀/뱃지, 'AI 추천' 태그·라벨) |
| `aiText` | `#A85400` | AI 추천 **이유 문장**처럼 읽어야 하는 AI 글자 (흰 배경 5.34:1). `ai`는 글자 대비 2.21:1이라 문장에는 쓰지 않는다 (2026-10-20) |
| `danger` | `#F0645A` | 오류, 로그아웃 |
| `dangerText` | `#C8463C` | 차단·삭제 같은 위험 동작의 **글자** (흰 배경 약 5:1, 2026-10-21). 시트에서는 구분선 아래 따로 떼어 두고 아이콘과 함께 쓴다 |
| `success` | `#16A07D` | 완료 |
| `extract` | `#8A63E6` | 추출 계열 보조(보라) |
| `kakao` | `#FEE500` | 카카오 버튼 (아이콘은 공식 말풍선 심볼 `KakaoSymbol`, 검정. 로그인 · 공유 모두) |

> `ai` 색은 **AI가 추천한 것에만** 쓴다 (선택 장소와의 시각적 구분이 핵심).

### 타이포 (Noto Sans KR, `AppTypography`)
| 토큰 | 크기 / 두께 | 용도 |
|------|-------------|------|
| `display` | 26 / 800 | 화면 대제목(가입 · 초대 수락) |
| `title` | 21 / 700 | 위저드 질문, 탭 화면 큰 제목 |
| `header` | 20 / 700 | 헤더 제목 |
| `section` | 18 / 700 | 섹션 제목 |
| `cardTitle` | 16 / 700 | 카드 · `SectionCard` 제목 |
| `bodyStrong` | 14 / 600 | 행 이름, 강조 본문 |
| `body` | 13 / 500 (`textSecondary`) | 본문 설명 |
| `button` | 15 / 700 | 버튼 |
| `label` | 13 / 700 | 입력 · 그룹 라벨 |
| `meta` | 12 / 500 (`textSecondary`) | 메타 한 줄 |
| `caption` | 11 / 500 (`textSecondary`) | 캡션 (SVG의 8.5–10px은 여기로 올림) |

### 형태
| 요소 | 값 |
|------|-----|
| 좌우 여백 | 20 (`AppSpacing.screenH`, 일부 24) |
| 입력 필드 | 높이 52, radius 15, `surface` + `border` |
| 주 버튼 | `AppButton` 높이 52, radius 16, 비활성은 투명도 40%. 종류: `primary` · `dark` · `soft` · `outline` · `white` |
| 하단 고정 버튼 | `BottomCta`: 바탕 `bg`, 여백 위 12 · 좌우 20 · 아래 16(SafeArea 포함) |
| 카드 | radius 20, `surface`(#F9FAFC) + `border` 1px, 그림자 없음 (2026-10-20) |
| 섹션 묶음 | `SectionCard`: 제목을 컨테이너 안에 두는 섹션 카드(제목 16/700, 안쪽 16). 탭 화면 본문은 바깥 여백 12 · 카드 사이 10 (2026-10-20, 홈부터) |
| 칩 | 높이 34, 풀 라운드, 선택=primary 채움 / 비선택=`surface`+`border` |
| 썸네일 | radius 14 |
| 뒤로가기 버튼 | **배경 없는 아이콘**(`PlainHeader`, 누르는 영역 48, 제목 17): 코스 화면 · 보관함 상세. 가입 화면은 `AuthHeader`(큰 제목 위 아이콘), 장소 상세는 사진 위 흰 원 버튼 — 2026-10-21, 10-30 07 D37 |
| 진행 바 | 4분할, 높이 4, radius 2, 활성 primary / 비활성 `divider` |
| 바텀시트 | 상단 radius 28 + 핸들 |
| 하단 탭 | 5개 (홈·저장됨·코스·추출·마이), 활성=primary + 연한 배경. 가운데 코스는 검정 사각형 버튼을 바 위로 조금 띄우고, 선택되면 파란색 (07 D31) |
| 간격 스케일 | 4 · 8 · 12 · 16 · 20 · 24 · 32 |

`AppColors / AppTypography / AppSpacing / AppRadius / AppShadow`로 먼저 토큰화하고, 화면마다 임의 값을 만들지 않는다.

## 4. 공통 컴포넌트

2026-10-30 코드(`lib/core/widgets/`, 각 기능의 `presentation/widgets/`) 기준 이름이다.

**기본 (`core/widgets`)**: `AppButton`(`primary`·`dark`·`soft`·`outline`·`white`) `AppTextLink` `AppIconBox` `AppTextField` `AppFieldError` `AppSearchField` `AppChip` `AppTextChip` `ChipScroller` `AppTag` `TagWrap` `CheckMark`(체크 아이콘만, 07 D26) `NumberBadge` `SegmentedTabs`(track / pills / underline) `KakaoSymbol` `AppLogo`
**헤더**: `PageTitleHeader`(탭 화면 큰 제목) `PlainHeader`(배경 없는 뒤로 + 제목) `AuthHeader`(가입 화면) `StepHeader`(위저드 뒤로 + 제목 + n/4) `StepProgressBar` `SectionHeader`
**표면 · 하단**: `SectionCard`(섹션 컨테이너, 제목 줄 오른쪽 `trailing`) `DividedRows`(컨테이너 안 구분선 행) `AppCard` `IconCircle` `BottomCta`(하단 고정 버튼 영역)
**오버레이**: `showAppSnackBar`(하단 고정 버튼이 있으면 그 위 8에 뜸, 07 D36) `showAppBottomSheet` `showAppModal` `showConfirmDialog` `showActionSheet`
**상태**: `AsyncValueView`(로딩 · 빈 · 오류를 한 번에) `AppLoading` `SkeletonBox` `SkeletonList` `AppEmptyState` `AppErrorState`
**사진 · 장소**: `PlaceImage`(사진 없으면 카테고리 색 칸 + 아이콘, 같은 크기 유지) `AppNetworkImage` `PlaceListTile` `SavedPlaceRow` `CollectionRow`(2×2 `MiniCollage`) `ExtractedPlaceRow` `RatingText` `AppliedFilterChip`(걸린 필터, 남색) `HeaderTextButton`
**홈**: `HomeCourseCard` `HomeQuickActions` `HomeStartGuide` `NewSavesNudge` `RecentSavedStrip` `SuggestedCourseStrip` `TrendingPlaceGrid`
**지도**: `AptMap`(네이버 · 웹 타일 · 미리보기 지도를 감쌈) `MapPin`(번호/선택/AI/내 위치) `MapPlacePicker`(지도 위 장소 고르기, 3단계 · 장소 추가 공용) `CourseRouteMap`
**코스**: `CourseHero`(이름 + 한 줄 정보) `CourseTimeline`(보기) `CourseEditList`(편집) `CourseEditButton` `StopMarker`(번호/✦) `CourseSummaryRow` `PickedTray` `RecommendingBanner`(추천 진행 · 취소) 장소 시트(`StopSheetAction`, 차단은 빨간 글자로 떼어 둠)
**파티 · 공유 · 인증**: `PartyAvatarStack` `ShareOption`(초대 · 코스 알리기 시트 공통) `SocialLoginButton` `SocialIconButton`
규칙: 페이지 안에서 같은 UI를 반복 작성하지 않는다. 새 화면 전에 **기존 컴포넌트를 검색해 재사용/확장**한다.

## 5. 아이콘 · SVG 사용 원칙

- SVG는 **참고 시안**이다. 화면 전체를 SVG로 넣지 않는다. 일러스트/로고/핀 같은 **자산 용도**로만 사용.
- 시안에 글자 기호로 그려진 아이콘(`↝ ⌂ ⌗ ▱ ○`, `✓ ! ✦ ≡ ⋮`)은 **실제 아이콘 세트**(Material Symbols 등)로 교체.
- 이동 수단(도보/버스/대중교통)도 아이콘 위젯 + 텍스트.
- SVG 속 사진/지도는 더미 → 실제 이미지 위젯/네이버 지도로 대체.
- 이미지 모서리는 `ClipRRect`.

## 6. 반드시 구현할 UI 상태

`Loading` `Empty` `Error` `Disabled` `Selected` `Saved` `AI Recommended` `Pressed`
- 모든 목록: 로딩 스켈레톤 · 빈 상태(행동 유도 문구 + CTA) · 오류(재시도)
- 폼: 기본 · 포커스 · 오류(인라인) · 비활성 버튼

## 7. 새 화면을 디자인할 때의 원칙 (디자인 언어 유지)

처음엔 추가 화면 3개(07, 08, 34)의 규칙이었고, 5개 탭(10-22)과 탭 밖 화면(10-30, 07 D37) 리디자인으로 아래처럼 정리됐다. 모든 화면이 이 언어를 따른다.

1. 배경 `#EEF1F5`, 카드/입력은 회백색 `#F9FAFC` + 얇은 `border`, 카드 안의 카드는 흰색. **그림자 없이** 밝기 3단계로 층을 나눈다 (2026-10-20)
2. 서브 화면 헤더 = **배경 없는 뒤로 아이콘 + 제목**(`PlainHeader`, 위저드는 `StepHeader` 우측 `n/4`). 흰 사각 뒤로 버튼(`SubPageHeader`)은 없앴다 (07 D37)
3. 인증/설정류 첫 화면은 **큰 제목(`display` 26/800) + 설명 + 입력들**, 주 버튼은 **`BottomCta`로 하단 고정**(키보드가 올라와도 가리지 않게)
4. 관련 항목은 **`SectionCard` 안 구분선 행(`DividedRows`)** 으로 묶는다. 선택형 항목은 높이 34 풀 라운드 칩, 라디오 · 체크는 `CheckMark`
5. 오류는 **빨강 테두리 + 아이콘 + 한 줄 메시지** (큰 별도 화면은 정말 필요한 때만). 상황 설명은 제목으로 올리고 장식용 `!` 원 카드는 쓰지 않는다 (07 D37)
6. 꾸미는 아이콘 원 · 일러스트를 넣지 않는다. 안내는 문장과 행동 버튼으로 (07 D37)
7. ✦ · 주황(`ai`)은 **AI가 추천한 장소 표시로만** 쓴다(태그 · 추천 이유). 제목 · 배경 · 버튼 장식 금지 (07 D17)
8. 하단 탭 화면(홈·저장됨·코스·추출·마이) 헤더는 **큰 제목 + 오른쪽 버튼만** 둔다. 정보 없는 분위기 부제는 쓰지 않는다 (2026-10-20, 07 D16)
9. 강조는 카드마다 한 곳만(예: 코스 카드는 D-day만 크게). 숫자 통계 타일은 쓰지 않는다 (2026-10-20, 07 D20)
10. 문구는 해요체, 짧고 행동 중심 ("~해주세요", "~할 수 있어요")
