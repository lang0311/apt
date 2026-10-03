# APT 졸업프로젝트 개발 방향 및 프로젝트 컨텍스트 (Flutter 앱)

> 이 문서는 기존 ChatGPT 프로젝트에서 논의·설계한 내용(`모바일 UI 피그마 만들기` 채팅 기록)과
> 이후 추가로 확정된 전제를 합쳐, 새 Codex Work / 개발 세션에서 바로 사용할 수 있도록 정리한 컨텍스트 문서다.
>
> **새 세션은 코드를 수정하기 전에 이 문서를 먼저 읽고, 현재 repository를 분석한 뒤 작업한다.**

---

## 0. 최우선 전제 (반드시 먼저 읽을 것)

| # | 전제 | 의미 |
|---|------|------|
| 1 | **클라이언트는 Flutter로 개발한다** | iOS / Android 단일 코드베이스. 모든 UI는 Flutter Native Widget으로 구현 |
| 2 | **백엔드/API/AI 서비스는 내가 구현하지 않는다. 제공받는다** | 앱 개발자는 **API 소비자(client)** 역할. DB 스키마를 설계·구현하지 않는다 |
| 3 | **API 명세(계약)가 Source of Truth** | 엔드포인트/필드/enum을 추측으로 만들지 않는다. 명세가 없으면 Repository Interface + Mock으로 분리하고 `NEEDS BACKEND`로 표시 |
| 4 | **장소 추천(LLM, 트렌드 반영, 취향 집계)은 백엔드/AI 서비스의 책임** | 앱은 "무엇을 위한 기능인지"를 이해하고, 입력을 올바르게 전달하고, 결과를 설득력 있게 보여주는 것까지만 담당 |

> ⚠️ 이전 채팅에서는 `졸프 db(1).xlsx`(DB 명세)를 분석하는 방향이 있었으나,
> 현재는 백엔드를 직접 만들지 않으므로 **DB 분석 대신 "제공받는 API 명세 기준 연동"**으로 방향을 바꾼다.
> 구체적인 테이블명/PK/FK/컬럼명은 이 문서에서 확정하지 않는다.

---

## 1. 프로젝트 한 문장 정의

> SNS(인스타그램 릴스 등)에서 발견한 장소를 **"공유" 한 번으로 앱에 가져와 자동으로 구조화·저장**하고,
> 개인 및 그룹(파티)의 취향을 반영해 **AI가 실제 방문 가능한 코스를 만들어 주는**
> 장소 저장·추천·코스 플랫폼.

## 2. 서비스 목적 (핵심 시나리오)

1. **장소 수집**: 인스타그램 릴스 같은 영상/게시물에서 **공유(Share) 기능으로 우리 앱에 전달** → 서버가 장소를 추출 → 사용자가 확인 후 저장
2. **장소 보관**: 저장한 장소를 카테고리별 목록/지도에서 탐색
3. **코스 생성**: 나중에 저장한 장소들을 바탕으로 **AI가 코스 생성을 도와줌** (순서, 이동, 추가 장소 추천)
4. **파티 코스**: 코스 생성 시 **파티를 만들 수 있음**. 이 경우 **파티원들의 취향을 종합**해 장소를 추천
   - 취향 정보 출처 (둘 다 가능):
     - (a) 파티원이 **미리 직접 입력**한 취향 (Explicit)
     - (b) 파티원 각자가 **이미 저장해 둔 장소**에서 추론한 취향 (Implicit)
5. **트렌디한 추천**: 장소 추천에는 LLM이 사용될 예정이며, **"트렌디한 곳을 추천한다"가 핵심 가치**
   - 이 로직은 백엔드/AI 서비스 영역. 앱은 이 목적을 이해하고 추천 이유/트렌드 정보를 UI에 잘 노출하면 된다.

### 전체 순환 구조 (서비스의 핵심 loop)

```
SNS 발견 → 공유 → 추출 → 저장 → 분류 → 지도 탐색 → 코스 생성
→ 개인/그룹 추천 → 실제 사용 → 행동 데이터 → 취향 개선 → 더 나은 추천
```

이 loop가 앱 안에서 끊기지 않게 연결되는 것이 UI/UX의 최우선 목표다.
**불필요한 입력을 최소화**한다. (공유 → 확인 → 저장이 몇 번의 탭으로 끝나야 함)

---

## 3. 책임 분담

### 3.1 앱(Flutter)이 하는 일
- 공유 진입(Share Intent / Share Extension), 링크 입력, 클립보드 감지
- 추출 요청 및 진행 상태 표시, 결과 확인/저장 UX
- 저장 장소/카테고리/지도/코스/파티/마이 UI
- 코스 편집(순서 변경), AI 추천 결과 표시, 경로 표시
- 취향 입력 UI(Explicit), 파티 생성/초대/참여 UI
- API 호출, 상태 관리, 캐싱, 에러/로딩/빈 상태 처리
- (백엔드가 지원한다면) 사용자 행동 이벤트 전송

### 3.2 앱이 하지 않는 일 (백엔드/AI 서비스 책임)
- SNS 게시물 분석 및 장소 추출
- Place 데이터 구축/정제, 카테고리 분류
- LLM 기반 장소 추천, 트렌드 반영
- 그룹 취향 집계(평균/최소 만족도/fairness 등) 알고리즘
- 경로/이동시간 계산(서버가 제공한다면 결과만 표시)
- DB 설계, 무결성, 인덱스, N+1 방지 등

> 앱은 위 항목에 대해 **"입력을 정확히 전달하고, 결과를 정확히 표시"**하는 데 집중한다.

---

## 4. 확정 / 미확정 구분

### 4.1 확정된 것 (도메인/UX 개념)
- 하단 네비게이션 5탭: `홈 | 코스 | 저장됨 | 추출 | 마이`
- Place(실제 장소)와 SavedPlace(사용자가 저장한 관계)는 **다른 개념**
- 카테고리는 **서버 데이터 기반 동적 UI** (프론트 하드코딩 금지)
- Course는 **순서가 있는** 장소 집합 (+ 일정/멤버/이동 정보)
- 개인 코스 / 파티 코스는 도메인 수준에서 구분되어야 함
- D-day는 저장하지 않고 **날짜에서 계산**
- AI 추천에는 **추천 이유**를 함께 표시
- 홈은 지도 중심이 아닌 **Dashboard형**
- SVG는 화면 전체가 아니라 **asset/component 용도**

### 4.2 미확정 (API 명세 수령 후 확정 — 추측 금지)
- 엔드포인트 경로, 요청/응답 필드명, 에러 포맷
- 인증 방식 (토큰/로그인/소셜 로그인 여부)
- 추출 방식 (동기 vs Job 기반 polling/푸시), 상태 enum
- Course type(PERSONAL/PARTY) 표현 방식, Party/Group 스키마
- 파티 초대 방식 (링크/코드/계정 검색), 멤버 권한
- 취향(Preference/Keyword) 입력·조회 스키마
- 추천 API 요청/응답 스키마 (추천 이유, 트렌드 정보 포함 여부)
- Interaction/Event 수집 API 존재 여부
- 경로(Route) / 이동시간 제공 방식 (서버 제공 vs 지도 SDK)

> 이 문서의 JSON/엔드포인트 예시는 **UI 요구사항을 설명하기 위한 예시**일 뿐 확정 계약이 아니다.

---

## 5. 하단 Navigation & Information Architecture

```
홈 | 코스 | 저장됨 | 추출 | 마이
```
- 순서는 특별한 이유가 없다면 유지한다.
- **각 탭의 책임을 섞지 않는다.**

```
APP
├── 홈
│   ├── 사용자 인사 / 프로필 요약
│   ├── 최근 활동
│   ├── 저장 장소 요약
│   ├── 진행 중 코스
│   ├── AI 추천 진입점
│   └── 추출 바로가기
│
├── 코스
│   ├── 코스 Empty State
│   ├── 개인 코스 목록
│   ├── 파티 코스 목록
│   ├── 코스 상세
│   ├── 코스 편집
│   ├── AI 코스 추천
│   ├── 경로 보기
│   └── 저장 완료
│
├── 저장됨
│   ├── 카테고리 목록
│   ├── 카테고리별 장소 목록
│   ├── 장소 상세
│   └── 지도로 보기
│
├── 추출
│   ├── 링크 입력 / 공유로 진입
│   ├── 추출 진행 중
│   └── 추출 결과 (확인 → 저장)
│
└── 마이
    ├── Profile
    ├── 취향 관리
    ├── 저장 장소 / 내 코스 / 파티 코스
    └── 계정 / 알림 / 앱 설정
```

---

## 6. 공유(Share) 진입 — 이 서비스의 핵심 진입 경로

> **중요 변경**: 이전 논의에서는 "1차 MVP는 앱 내부 URL 붙여넣기로 충분, Share Extension은 후순위"였다.
> 그러나 서비스 목적이 "**릴스 등에서 공유를 통해 앱으로 보내는 것**"이므로 **공유 진입을 핵심 기능(MVP)으로 격상**한다.
> 링크 붙여넣기는 **보조/폴백 경로**로 유지한다.

### 6.1 진입 경로
```
Instagram(릴스/게시물)
   ↓ 공유 버튼
공유 시트에서 APT 선택
   ↓
APT가 URL(또는 텍스트) 수신
   ↓
추출 요청 → 진행 상태 표시
   ↓
장소 후보 확인 → 저장(카테고리 선택)
```

### 6.2 구현 우선순위
1. **Android Share Intent 수신** (`text/plain` 공유 수신)
2. **iOS Share Extension** (별도 타깃 필요, 앱과 데이터 전달 방식 설계 필요 — App Group 등)
3. 앱 내부 링크 입력 (폴백)
4. Clipboard detection (복사된 링크 감지 시 "추출할까요?" 제안)

### 6.3 UX 원칙
- 공유로 진입하면 **추출 화면으로 바로 이동**하고 자동으로 추출을 시작한다 (추가 입력 최소화).
- 앱이 종료된 상태 / 실행 중 상태 / 백그라운드 상태 모두에서 공유 수신이 동작해야 한다.
- 지원하지 않는 링크/형식이면 명확한 에러와 대안(직접 입력)을 제공한다.
- 참고 디자인 SVG: `instagram_share_sheet_layered.svg`, `instagram_share_sheet_pixel_closer_layered.svg`
  (Instagram → 앱 공유 진입 경험 참고용이며 **앱 본체 UI가 아님**)

---

## 7. 추출 UX

### 7.1 기본 흐름
```
(공유 수신 또는 링크 입력)
   ↓
추출 시작 → 서버 분석 → 장소 후보 추출
   ↓
사용자 확인
   ├─ 저장됨에 추가
   └─ 코스에 추가
```

### 7.2 추출 입력 화면 (폴백 경로)
- 제목, 설명, URL 입력창, 붙여넣기 버튼, 추출 버튼, 최근 추출 내역(optional)
- URL 형식 validation 필요

### 7.3 추출 중
단순 spinner보다 **현재 상태를 보여준다.**
```
게시물을 확인하고 있어요 → 장소 정보를 찾고 있어요 → 거의 다 됐어요
```
- 백엔드에 실제 status가 있다면 연결 (예: PENDING / PROCESSING / COMPLETED / FAILED — **실제 enum은 API 명세 기준**)
- 실패 시: 재시도, 직접 입력 폴백 제공

### 7.4 추출 결과
- 원본 SNS 게시물 정보와 추출된 장소가 **함께** 보여야 한다.
- 장소 여러 개일 수 있음 → 개별 [저장] + [선택한 장소로 코스 만들기]
- 저장 시 카테고리 선택(서버가 제공하는 카테고리 목록 사용)

```
Instagram 게시물
─────────────────
추출된 장소 2곳
1. 카페 A  서울 성동구...  [저장]
2. 음식점 B 서울 성동구...  [저장]
[선택한 장소로 코스 만들기]
```

---

## 8. 저장됨 UX

### 8.1 저장됨 메인
- 카테고리는 **프론트에 하드코딩하지 않는다.** 서버 응답으로 동적 렌더링.
- 카테고리 카드에 필요한 정보(예): categoryId, categoryName, savedPlaceCount, 대표 이미지, (필요 시) 최근 저장 장소
- 카테고리 클릭 → 해당 카테고리 장소 목록

### 8.2 개념 구분
```
Place      = 서비스가 알고 있는 실제 장소
SavedPlace = 특정 User가 해당 Place를 저장했다는 관계 (+ 카테고리 등 사용자별 속성)
```

### 8.3 저장 장소 지도 ([지도로 보기])
- 사용자의 **저장 장소만** 표시 (전체 Place 데이터를 내려받지 않는다)
- 지도에 필요한 최소 정보(예): savedPlaceId, placeId, placeName, latitude, longitude, categoryId/Name, thumbnail
- 지도 이동 시 **viewport(bounding box) 기반 조회 + debounce** (API가 지원하는 경우). 지원하지 않으면 전체 로드 후 클라이언트 clustering 고려 → 백엔드와 협의
- 매 프레임 서버 호출 금지

### 8.4 Pin 디자인 / 상태
- 짧고 compact한 **Google Maps / iOS 계열 pin 스타일** (`google_maps_ios_style_pin_component.svg` 기준, `modern_map_pin_component.svg`는 세로가 길어 폐기)
- 상태: `default` / `selected` / `course`(순번 표시) / `AI recommended`
- 카테고리 색을 핀 전체에 과도하게 적용하지 않고, 작은 accent나 내부 번호/아이콘으로 구분

---

## 9. 코스 UX

### 9.1 개념
- 코스는 **순서가 있는 장소들의 집합**. CoursePlace에는 순서 정보 필요 (필드명은 API 기준).
- 코스는 장소 순서 외에 일정(날짜), 멤버, 이동 정보를 가질 수 있다.

### 9.2 Empty State
코스가 없으면 빈 리스트 대신 행동 유도:
```
아직 만든 코스가 없어요
저장한 장소를 연결해서 나만의 코스를 만들어보세요.
[코스 만들기]   AI에게 추천받기
```

### 9.3 코스 목록
- 카드 기반. 예: `성수 데이트 코스 / 성수 · 서울숲 / 4개 장소 / 카페 → 전시 → 음식점 → 바`
- **개인 코스**와 **파티 코스(👥)**를 시각적으로 구분하되, 완전히 다른 디자인 시스템은 쓰지 않는다.
- 목록 API가 카드 렌더링에 필요한 summary(placeCount, thumbnail, memberCount 등)를 제공하는 것이 이상적 (N+1 방지 — 필요 시 백엔드에 요청)

### 9.4 코스 편집 화면 (가장 많이 작업한 화면)
```
Navigation
Course title
Map
Course Place List   ← 순서 변경(드래그) 가능해야 함
AI Recommendation
Save
```

### 9.5 AI 추천 장소 표현
- 사용자가 직접 추가한 장소와 **시각적으로 구분**
- 표시 정보: `AI 추천` 라벨, 장소 이름, 카테고리, **추천 이유**, 기존 코스와의 거리
- 참고 SVG: `ai-summary-card.svg`, `place-row-ai-recommended.svg`, `place-row-ai-recommended-1.svg`, `ai-recommendation-sheet.svg`

### 9.6 AI 추천 Bottom Sheet
```
Map
────────────
Bottom Sheet
  AI 추천 결과
  장소 A
  장소 B
  [코스에 적용]
```
지도 context를 유지하면서 추천 결과를 비교한다.

### 9.7 코스 경로 표시
- **핀 중심을 단순 직선으로 연결하지 않는다.** 가능하면 실제 도로/이동 경로와 일치하게 표시.
- 코스는 segment 단위: `Place 1 → Segment 1 → Place 2 → Segment 2 → Place 3`
- Segment 정보(예): transportType, duration, distance, polyline (**제공 여부/형식은 API 기준**)
- 이동 수단 아이콘은 SVG에 억지로 재현하지 말고 **Flutter의 Material Symbols/Icons 사용**
  - 도보 `directions_walk`, 버스 `directions_bus`, 대중교통 `directions_transit`
- 경로 보기는 **Toggle** (OFF: 핀만 / ON: 핀 + 이동 경로 + 이동 시간). 경로 계산 비용을 고려해 필요 시에만 활성화.
- 참고 SVG: `ai_route_overlay_*`, `ai_route_split_1_2_2_3_3_4.svg`, `ai_route_split_with_transit_times.svg`, `transport_duration_pills_icon_slots.svg`, `duration_pill_*`

### 9.8 코스 저장 UX
```
코스 편집 → 저장 → 저장 중 → 저장 완료 → Bottom Sheet
  "코스가 저장됐어요"  [코스 확인하기]  [계속 편집하기]
```
- [코스 확인하기] → **저장된 코스 지도 화면** (전체 저장 장소가 아니라 **해당 코스의 장소만** 표시)
```
Course Name
Map (Pin 1..N)
Bottom Sheet: Course Place List / 경로 보기 / 코스 편집
```

---

## 10. 파티 코스 & 취향

### 10.1 개인 코스 vs 파티 코스
```
개인 코스: owner = User, participants = 본인
파티 코스: owner + 여러 멤버 + 그룹 취향 + 이벤트 날짜 + 멤버 권한
```
- 구분 방식(Course type 필드 vs Party 연결)은 **API 명세 기준**.

### 10.2 파티 흐름 (Journey)
```
파티 생성 → 멤버 초대 → 멤버 참여 → 취향 통합(서버) → AI 추천
→ 장소 조정 → 코스 확정 → D-day → 경로 보기
```

### 10.3 파티원 취향 정보 소스
| 소스 | 설명 | 앱의 역할 |
|------|------|-----------|
| Explicit | 파티원이 미리 입력한 취향(카페/전시/한식/조용한 곳/데이트/사진 찍기 좋은 곳 등) | 입력/수정 UI 제공 (온보딩, 마이 → 취향 관리, 파티 참여 시) |
| Implicit | 파티원 각자 저장한 장소·행동에서 추론 | 사용자에게 "저장 장소 기반으로 취향 분석 완료" 같은 상태 표시. 계산은 서버 |

- 파티 화면 예: `성수 생일 파티 / D-4 / 멤버 아바타 / 우리 취향 분석 완료 / [AI 코스 추천 받기]`
- 그룹 취향 집계 방식(평균/최소 만족도/fairness/공통 키워드/선호 분산)은 서버(알고리즘) 영역. 앱은 결과와 **설명**을 보여준다.
- **프라이버시 고려**: 파티원의 저장 장소/취향을 다른 멤버에게 어디까지 노출할지는 서버 정책 확인 후 결정 (UI에서 임의로 개별 취향을 공개하지 않는다).

### 10.4 D-day
- 이벤트 날짜(eventDate)를 받아 **클라이언트에서 D-day를 계산**한다. D-day 값 자체를 서버 필드로 가정하지 않는다.

---

## 11. AI 추천 UX (LLM 기반 — 앱은 소비자)

- 추천 엔진은 LLM을 사용하며 **트렌디한 장소 추천이 핵심 가치**다. (구현은 백엔드/AI 서비스)
- 앱의 역할:
  1. **입력 전달**: 코스 ID, 파티 멤버, 제약(지역/최대 장소 수 등) — 실제 파라미터는 API 기준
  2. **결과 표시**: 추천 장소 + **추천 이유**를 사람이 이해할 수 있는 문장으로 표시
  3. **피드백 수집**: 수락/무시/삭제 등 사용자 반응을 (지원 시) 서버에 전달
- 추천 이유 표시 예 (서버가 제공하는 텍스트/태그를 그대로 활용):
  - "멤버 4명 중 3명이 카페를 선호해요."
  - "현재 코스에서 도보 6분 거리예요."
  - "요즘 SNS에서 많이 언급되는 곳이에요." (트렌드 정보가 제공될 경우)
- **로딩 UX**: LLM 응답은 지연될 수 있으므로 단계별 진행 메시지/스켈레톤, 타임아웃/재시도 처리 필수
- **빈 결과/실패** 상태도 반드시 설계 (조건 완화 제안 등)
- 점수(score) 같은 내부 값은 그대로 노출하지 않는다. 사람이 이해하는 설명으로 변환.

### 11.1 Recommendation API 예시 (예시일 뿐, 확정 아님)
```http
POST /courses/{courseId}/recommendations
```
```json
// request
{ "memberIds": [1, 2, 3], "constraints": { "area": "성수", "maxPlaces": 4 } }
// response
{
  "recommendationId": 101,
  "places": [
    { "placeId": 11, "name": "Example Cafe", "score": 0.91,
      "reasons": ["3명의 취향과 일치", "현재 코스에서 도보 5분"] }
  ]
}
```
실제 API 계약은 백엔드 제공 명세를 따른다.

---

## 12. 홈 / 마이 화면

### 12.1 홈 (Dashboard형, 지도 중심 아님)
- 사용자 영역: 인사 + nickname + profile image
- 저장 장소 요약: 총 개수 + 카테고리별 개수 → **서버 aggregate 결과 사용** (프론트에서 전체 목록으로 count 금지)
- 진행 중 코스: 최근 수정 코스 또는 일정이 가까운 코스 (예: `성수 데이트 코스 · 4개 장소 · D-3`)
- AI 추천: 전체 기능이 아니라 **진입점** (`[AI 코스 추천 받기]`)
- 추출 바로가기
- 지도는 홈에 두지 않고 `저장됨 → 지도로 보기` 또는 `코스 상세`에서 사용

### 12.2 마이
- 설정 화면만 되어서는 안 된다. 사용자 활동과 취향을 보여준다.
- 구성: Profile / 취향(`#카페 #전시 #한식 #조용한곳` + [수정]) / 저장 장소 / 내 코스 / 파티 코스 / 계정 / 알림 / 앱 설정
- 취향 관리는 추천 알고리즘이 사용자에게 보이는 접점이다.

---

## 13. 디자인 방향 & 디자인 시스템

### 13.1 키워드
`Clean` `Modern` `iOS-like` `Map friendly` `Content first` `Bottom sheet oriented` `Minimal`
- 화면에 너무 많은 정보를 한 번에 보여주지 않는다.

### 13.2 화면 프레임 기준 (피그마/디자인 산출물 기준)
- **모든 화면은 동일한 모바일 프레임 비율/크기를 사용한다. (393 × 852 기준)**
- 홈/코스/저장됨/추출/지도/파티/마이 등 모든 스크린의 프레임 높이를 동일하게 고정하고,
  내용이 많으면 **스크롤되는 화면처럼** 구성한다 (콘텐츠 양에 따라 프레임 높이가 달라지면 안 됨).

### 13.3 Design Token (Flutter 구현 전에 먼저 구축)
- `AppColors` (primary, background, surface, textPrimary, textSecondary, border …)
- `AppTypography` (titleLarge, titleMedium, body, caption …)
- Spacing 스케일: `4, 8, 12, 16, 20, 24, 32` — 임의 padding 값을 화면마다 새로 만들지 않는다.

### 13.4 공통 컴포넌트 (먼저 만든다)
```
AppButton, AppIconButton, AppBottomSheet, AppCard, AppChip,
AppLoading, AppEmptyState, AppErrorState,
PlaceCard, SavedPlaceCard, CategoryCard, CourseCard, CoursePlaceRow,
PartyCourseCard, MapPin, TransportDurationChip, AIRecommendationCard, ProfileAvatar
```
- 페이지 내부에서 동일한 UI를 반복 작성하지 않는다.
- 새 화면 작성 전 기존 컴포넌트를 검색하고 **재사용/확장**한다.

### 13.5 SVG / Figma → Flutter 원칙
- SVG를 화면 전체에 넣지 않는다. SVG는 **icon / map pin / illustration / 일부 vector component** 용도.
- Figma 전체 화면은 **Flutter Widget으로 재구현**한다. 픽셀 복사보다 **디자인 의도 + 정보 위계 + 사용자 행동 + 상태 변화**를 유지한다.
- 이동 수단 등 아이콘은 SVG로 재현하지 말고 Flutter Icon/Material Symbols 사용.
- 이미지 모서리 radius는 `ClipRRect` 등으로 처리.
- Figma 쪽 메모: Layer panel은 위=front/아래=back, 가로 리스트는 Clip content ON, Prototype navigation은 SVG가 아니라 Figma에서 연결.

### 13.6 반드시 구현할 UI 상태
`Loading` `Empty` `Error` `Disabled` `Selected` `Saved` `AI Recommended`

---

## 14. Flutter 아키텍처

### 14.1 구조 (feature-first 권장)
```
lib/
├── app/        (app.dart, router.dart, theme/)
├── core/       (network/, error/, utils/, widgets/)
└── features/
    ├── home/
    ├── course/
    ├── saved/
    ├── extraction/   ← 공유 수신 포함
    ├── map/
    ├── party/
    ├── recommendation/
    └── my/
```
Feature 내부 예시:
```
features/saved/
├── data/          (datasource/, dto/, repository/)
├── domain/        (model/, repository/)
└── presentation/  (page/, widget/, provider/)
```
- 졸업프로젝트 규모에 비해 **과도한 Clean Architecture는 피한다.** 목표는 구조적 분리이지 파일 수 증가가 아니다.
- **기존 프로젝트 구조가 있다면 그것을 우선한다.** 임의로 새 architecture를 만들지 않는다.

### 14.2 데이터 흐름
```
API Response(DTO) → mapper → Domain Model → Provider/Controller → Widget
```
- API JSON을 Widget에서 직접 참조하지 않는다. (`Text(json['place']['name'])` ❌ → `Text(place.name)` ✅)
- UI가 서버 응답 구조를 그대로 노출하지 않는다.

### 14.3 상태 관리
- 모든 서버 연동 화면은 최소 `initial / loading / success / empty / error / refreshing` 고려
- Riverpod 사용 시 `AsyncValue` 기반 단순화 (**기존 프로젝트의 state management를 먼저 확인하고 따른다**)

### 14.4 서버가 Source of Truth
- 카테고리, 저장 장소, 코스, 파티 등 서버 데이터는 UI에 하드코딩하지 않는다.
- API가 아직 없으면: `Repository Interface → Mock Repository` 형태로 분리. **Widget 내부에 mock JSON을 직접 넣지 않는다.**

### 14.5 라우팅 (declarative routing, 예: go_router)
```
/home
/courses, /courses/:id, /courses/:id/edit
/saved, /saved/categories/:id, /saved/map
/extract, /extract/:id/result
/my
/parties/:id, /parties/:id/course
```
- 공유 수신 시 `/extract`(또는 결과 화면)로 deep link 형태로 진입하는 라우팅을 고려한다.

---

## 15. 성능 & 네트워크

- **지도**: marker rebuild 최소화, viewport query debounce, clustering 고려, polyline 캐싱
- **이미지**: network image cache, thumbnail 사용, 원본 이미지 무조건 다운로드 금지
- **저장 장소 목록**: pagination(cursor 방식이 제공되면 사용) + lazy loading
- **코스**: 상세 API 한 번으로 필요한 summary를 받도록 (부족하면 백엔드에 요청)
- **네트워크 에러**: 타임아웃, 재시도, 오프라인 안내. 추출/추천처럼 오래 걸리는 요청은 취소·재시도 UX 제공

---

## 16. 사용자 행동 이벤트 (추천 피드백)

추천 품질 개선을 위해 사용자 행동이 서버로 전달되면 좋다. **수집 API가 제공될 때만** 연동하고, 없으면 `NEEDS BACKEND`로 기록.
```
PLACE_VIEW / PLACE_SAVE / PLACE_UNSAVE
COURSE_CREATE / COURSE_PLACE_ADD / COURSE_PLACE_REMOVE / COURSE_REORDER / COURSE_SAVE
RECOMMENDATION_VIEW / RECOMMENDATION_ACCEPT / RECOMMENDATION_REJECT
CATEGORY_VIEW
EXTRACTION_START / EXTRACTION_SUCCESS / EXTRACTION_FAIL
```
- 이벤트 이름·스키마는 후보일 뿐이며 서버 명세를 따른다.
- 추천 연구와 제품 구현을 분리하지 않는다: `사용자 행동 → 취향 → 추천 → UI → 사용자 선택 → Feedback` loop가 앱에서 완성되어야 한다.

---

## 17. 핵심 User Journey

**A. 공유로 장소 저장 (핵심)**
```
Instagram 릴스 → 공유 → APT 선택 → 자동 추출 → 장소 확인 → 카테고리 선택 → 저장 → 저장됨
```
**B. 저장 장소 지도 탐색**
```
저장됨 → 카테고리 → 지도로 보기 → Pin 선택 → 장소 상세
```
**C. 개인 코스**
```
코스 → 코스 만들기 → 저장 장소 선택 → 순서 설정 → AI 추천 → 코스 저장 → 코스 확인 → 경로 보기
```
**D. 파티 코스**
```
파티 생성 → 멤버 초대 → 멤버 참여(취향 입력/저장 장소 기반) → AI 추천 → 장소 조정 → 코스 확정 → D-day → 경로 보기
```

---

## 18. 개발 우선순위

| Phase | 내용 |
|-------|------|
| 1. Skeleton | Bottom Navigation, Router, Theme(토큰), API Client, Error handling, 공통 컴포넌트 |
| 2. Saved Place | 저장 카테고리, 장소 리스트, 장소 상세, 지도 (가장 먼저 실제 데이터 연결) |
| 3. Extraction + Share | **공유 수신(Android Intent → iOS Extension)**, 링크 입력 폴백, 추출 진행/결과/저장 |
| 4. Course | 코스 목록, 생성, 장소 추가, 순서 변경, 저장, 상세 |
| 5. Route | Map Pin, Route polyline, Transport segment, duration |
| 6. AI Recommendation | 취향 입력 UI, Recommendation 호출, AI 추천 장소/추천 이유, 코스 반영 |
| 7. Party Course | Party, Member, Invite, 취향 통합 결과 표시, 파티 추천, D-day |
| 8. Home / My polish | 실제 데이터 기반 Dashboard, 마이 정리 |

> API가 아직 없는 Phase는 Repository Interface + Mock으로 UI를 먼저 완성하고, 명세 수령 후 실제 연동으로 교체한다.

### MVP 필수
공유/URL 입력 → 장소 추출 → 저장 → 동적 카테고리 → 저장 장소 목록/지도 → 개인 코스 생성(순서) → 코스 저장/상세 → AI 추천 → 사용자 취향

### 이후 확장
실시간 Party Editing, Push Notification, 친구 시스템, 코스 공유/공개 코스, 추천 피드, 방문 인증, 리뷰, 코스 복제 — MVP를 방해하면 뒤로 미룬다.

---

## 19. 피해야 할 방향

1. 홈을 지도 앱처럼 만드는 것
2. 카테고리 하드코딩
3. Place와 SavedPlace 혼동
4. Course를 단순 Place List로 취급 (순서/일정/멤버/이동 정보 필요)
5. 개인/파티 코스를 UI에서만 구분 (모델 수준에서 표현)
6. D-day를 값으로 저장/가정 (날짜에서 계산)
7. 추천 결과만 표시하고 사용자 반응(피드백)을 무시
8. 전체 화면을 SVG로 사용
9. **API 명세가 불명확한 부분을 추측해서 구현** (테이블/필드/enum/status/nullable 임의 생성 금지)
10. 공유 진입을 후순위로 미루어 "링크 복사-붙여넣기"만 만드는 것

---

## 20. 기존 SVG / 디자인 에셋 목록 (레퍼런스)

> 이 파일들은 별도로 제공되는 디자인 레퍼런스다. 일부는 UI 수정 이전 산출물이므로
> **UX 구조 참고용**으로 쓰고 최신 컴포넌트 스타일을 우선한다.

- **Edit**: `edit_button_component.svg`
- **Map Pin**: `google_maps_ios_style_pin_component.svg` (최신 방향), `modern_map_pin_component.svg` (초기, 폐기 방향)
- **AI Course**: `ai-recommendation-sheet.svg`, `course-title-row.svg`, `place-list-section.svg`, `bottom-action-area.svg`, `ai-summary-card.svg`, `place-row-ai-recommended.svg`, `place-row-ai-recommended-1.svg`, `Counter 3.svg`, `Counter 4.svg`
- **Route**: `ai_recommendation_connected_counters_only.svg`, `ai_route_overlay_only_following_road.svg`, `ai_route_overlay_only_map_harmonized.svg`, `ai_route_overlay_road_matched.svg`, `ai_route_overlay_main_road_matched.svg`, `ai_route_split_1_2_2_3_3_4.svg`, `ai_route_split_with_transit_times.svg`
- **Transport**: `transport_duration_pills_icon_slots.svg`, `duration_pill_walk_5min_no_icon.svg`, `duration_pill_bus_9min_no_icon.svg`, `duration_pill_bus_15min_no_icon.svg`
- **UX Flow**: `flow_01_editor.svg`, `flow_02_saving.svg`, `flow_03_save_success.svg`, `flow_04_saved_map.svg`, `flow_05_route_on.svg`, `ux_flow_board.svg`
- **Instagram 공유 진입 참고**: `instagram_share_sheet_layered.svg`, `instagram_share_sheet_pixel_closer_layered.svg`

---

## 21. Codex 개발 규칙

### 21.1 작업 시작 시 (코드 수정 전에 먼저)
1. repository tree 확인
2. Flutter 버전 / `pubspec.yaml` 확인
3. 현재 구현된 화면 확인
4. router / state management / API client 확인
5. API 명세(또는 DTO/backend 문서) 확인
6. SVG/assets 확인
7. 현재 구현과 이 문서의 차이 분석

기능은 아래 4개 상태로 분류해 보고한다:
`IMPLEMENTED` / `PARTIAL` / `NOT IMPLEMENTED` / `NEEDS BACKEND`

### 21.2 보고 형식
```
## Current Architecture
## Existing Screens
## Existing Models
## Existing APIs
## Existing Assets
## Existing State Management
## Existing Navigation
## Gap Against DEVELOPMENT_DIRECTION.md
### Implemented / Partial / Not Implemented / Needs Backend
```
그 뒤 사용자와 **구현 범위를 확인**하고 작업한다.

### 21.3 원칙
- 기존 코드를 무시하고 새로 작성하지 않는다. `Inspect → Understand → Compare → Plan → Implement → Test` 순서.
- 기존 컴포넌트(Button, Card, BottomSheet, PlaceCard, CourseCard, MapPin 등)를 먼저 검색해 재사용한다.
- API가 준비되어 있으면 실제 API 사용. 없으면 Repository Interface + Mock Repository로 분리.
- **API 명세와 이 문서가 충돌하면 임의로 한쪽을 선택하지 말고**, 충돌 지점을 명시한 뒤 수정 방향을 제안한다.
- 이 문서의 숫자/가중치/JSON 예시는 확정값이 아니다 (특히 추천 가중치).

### 21.4 권장 문서 유지 (`docs/`)
```
docs/
├── DEVELOPMENT_DIRECTION.md   (이 문서)
├── API_CONTRACT.md            (엔드포인트, Request/Response, Error, Pagination, Auth, 사용 화면)
├── API_UI_MAPPING.md          (API 필드 → Flutter Model → Provider → Widget 매핑)
├── UX_FLOW.md                 (Extraction / Save / Course Creation / Course Save / Party / Recommendation Flow)
└── TODO.md
```
`API_UI_MAPPING.md` 예시:
```
GET /saved/categories(예시) → SavedCategoryDto → SavedCategory → SavedCategoryProvider → CategoryCard
```
이렇게 해야 백엔드 변경이 UI에 미치는 영향을 추적할 수 있다.

---

## 22. 핵심 원칙 요약

1. **공유(Share)를 통한 SNS 장소 추출**이 주요 acquisition flow다.
2. 저장 장소가 서비스 데이터의 핵심 자산이다.
3. 저장 카테고리는 서버 기반으로 동적 구성한다.
4. 지도는 저장 장소와 코스를 탐색하는 수단이다.
5. Place와 SavedPlace를 구분한다.
6. Course에는 장소 순서가 존재한다.
7. 개인 코스와 파티 코스를 구별한다.
8. 파티 코스는 그룹 취향 추천(서버)과 연결한다. 취향은 직접 입력 + 저장 장소 기반 두 경로가 있다.
9. D-day는 날짜에서 계산한다.
10. AI(LLM) 추천은 **트렌디한 장소 추천**이 목적이며, 결과에는 추천 이유를 제공한다.
11. 사용자 행동을 추천 피드백 데이터로 활용한다(서버 지원 시).
12. SVG는 asset/component reference로만 사용하고 화면은 Flutter Widget으로 구현한다.
13. API/DTO 구조를 Widget에 직접 노출하지 않는다.
14. loading / empty / error / success 상태를 모두 설계한다.
15. **API 명세가 불확실한 부분을 임의로 만들어서는 안 된다.**
16. 모든 디자인 프레임은 동일한 393×852 기준을 유지한다.

---

## 부록. 이 문서의 출처와 한계

- 출처: ChatGPT 프로젝트 채팅 `모바일 UI 피그마 만들기`의 개발 방향 문서(DEVELOPMENT_DIRECTION) + 사용자가 추가로 확정한 전제(Flutter, 백엔드는 제공받음, 공유 기반 추출, 파티 취향 소스, LLM 트렌드 추천).
- 원본 채팅 기록에서 문서 앞부분(1~2장: 프로젝트 개요/핵심 기능 정의)은 열람된 텍스트에 포함되지 않아, 해당 내용은 사용자 설명과 이후 장 내용을 바탕으로 재구성했다.
- 기존 문서의 "DB 명세(`졸프 db(1).xlsx`) 기준" 지침은 "제공받는 API 명세 기준"으로 대체했다. DB 명세 파일이 함께 제공되는 경우에도 **앱은 API 계약을 기준**으로 하고, DB 파일은 데이터 의미 이해용 참고 자료로만 사용한다.
