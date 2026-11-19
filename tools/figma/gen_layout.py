# 섹션별 레이아웃 데이터(JSON) 생성: 화면 제목 · 누르는 곳 · 동작 표 · 화살표
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import taps as T

SECTIONS = [
    ('1', '로그인 · 가입', '소셜 로그인이 기본이고 아이디 로그인 · 가입도 같은 화면에서 해요.', '앱을 처음 켤 때 · 로그아웃한 뒤',
     [('a01', '로그인'), ('a02', '로그인 오류'), ('a03', '약관 동의'), ('a04', '약관 동의 · 모두 선택'), ('a05', '프로필 설정'), ('a06', '가입 완료'), ('a07', '아이디 가입 · 중복 오류'), ('a08', '계정 충돌'), ('a09', '로그인 실패')]),
    ('2', '홈', '하단 탭 ①. 다가오는 코스 · 바로가기 · 지역별 시작 · 최근 저장 · 추천 코스 · 지금 뜨는 장소.', '로그인 · 가입 완료 뒤, 하단 탭 홈',
     [('b01', '홈'), ('b02', '홈 · 아래쪽')]),
    ('3', '저장됨 · 장소 상세', '하단 탭 ②. 지역별 · 업종별로 보고, 필터로 좁히고, 장소를 눌러 자세히 봐요.', '하단 탭 저장됨 · 홈의 모두 보기 · 홈 사진 카드',
     [('c01', '저장됨'), ('c02', '필터 시트'), ('c03', '필터 적용'), ('c04', '장소 상세'), ('c05', '장소 상세 · 아래쪽'), ('c06', '보관함 변경 시트')]),
    ('4', '보관함 · 저장 지도', '저장됨의 보관함 탭과 저장 지도.', '저장됨 · 보관함 탭',
     [('c07', '보관함 목록'), ('c08', '보관함 상세'), ('c09', '새 보관함'), ('c10', '빈 보관함'), ('c11', '저장 지도')]),
    ('5', '장소 추가 · 장소 찾기', '하단 탭 ④. 릴스 공유 · 링크 입력 · 지도에서 검색하기.', '릴스 공유 · 하단 탭 장소 추가',
     [('d01', '장소 추가'), ('d02', '찾는 중'), ('d03', '찾은 장소'), ('d04', '보관함 고르기'), ('d05', '저장 완료'), ('d06', '비공개 게시물'), ('d07', '지도에서 검색')]),
    ('6', '코스 만들기 (1/4 → 4/4 → 저장)', '정보 → 동행 → 장소 → AI 추천, 4/4에서 다시 추천을 반복할 수 있어요.', '하단 탭 코스 · 홈의 코스 만들기 · 장소 상세의 이 장소로 코스 만들기',
     [('e01', '코스 목록'), ('e02', '1/4 정보'), ('e03', '출발 시간 시트'), ('e04', '1/4 정보 · 입력 뒤'), ('e05', '2/4 동행 · 혼자'), ('e06', '2/4 동행 · 새 파티'), ('e07', '파티원 초대 시트'), ('e08', '2/4 동행 · 기존 파티'),
      ('e09', '3/4 장소 · 지도'), ('e10', '3/4 장소 · 목록'), ('e11', '4/4 추천 중'), ('e12', '4/4 추천 결과'), ('e13', '4/4 추천 결과 · 아래쪽'), ('e14', '파티원 알림 시트'), ('e15', '코스 상세 · 저장 직후')]),
    ('7', '코스 상세 · 편집', '저장한 코스를 보고 일정을 고쳐요.', '코스 목록 · 코스 저장 뒤',
     [('e16', '코스 상세'), ('e17', '일정 편집'), ('e18', '일정 편집 · 장소 뺌'), ('e19', '코스 · 함께하는 코스')]),
    ('8', '초대', '파티 초대 링크를 열었을 때.', '파티 초대 링크',
     [('f01', '초대 수락'), ('f02', '초대 만료')]),
    ('9', '마이', '하단 탭 ⑤. 내 정보 · 취향 · 추천하지 않는 장소 · 로그아웃.', '하단 탭 마이',
     [('g01', '마이'), ('g02', '취향'), ('g03', '추천하지 않는 장소'), ('g04', '로그아웃 확인')]),
]

NAMES = {}  # id -> (section, num, title, fullname)
for sec, title, sub, entry, scr in SECTIONS:
    for i, (sid, t) in enumerate(scr, 1):
        NAMES[sid] = (sec, i, t)

ALL = {}
for p in __import__('glob').glob('final/*.json'):
    n = os.path.basename(p)[:-5]
    ALL[n[:3]] = n


def ref(sid, same=False):
    sec, num, t = NAMES[sid]
    return f"{num:02d} {t}" if same else f"[{sec}] {num:02d} {t}"

# 규칙: (screen, cmp 접두, 라벨/툴팁 포함어, n번째, 결과 텍스트, 종류, 목적지)
# 종류: same(같은 섹션 화면 · 파랑) · other([n] · 검정) · stay(같은 화면 · 회색) · back
R = [
    ('a01', 'AppTextLink', '회원가입', 0, None, 'same', 'a07'),
    ('a01', 'SocialIconButton', '', 0, '카카오 → 약관 동의(신규) · Google → [2] 01 홈(기존)', 'same', 'a03'),
    ('a02', 'AppButton', '다시', 0, None, 'same', 'a01'),
    ('a02', 'AppTextLink', '고객센터', 0, '메일 앱 열기', 'stay', None),
    ('a03', 'DividedRows', '', 0, '전체 동의 · 항목 체크 → 04 약관 동의 · 모두 선택', 'same', 'a04'),
    ('a03', 'DividedRows', '', 1, '약관 전문 보기 (준비 중 알림)', 'stay', None),
    ('a04', 'AppButton', '동의하고', 0, None, 'same', 'a05'),
    ('a05', 'AppButton', '가입', 0, None, 'same', 'a06'),
    ('a05', 'SectionCard', '', 0, '취향 고르기 (서버 모드는 저장한 곳 기준 설명)', 'other', 'g02'),
    ('a06', 'AppButton', '시작하기', 0, None, 'other', 'b01'),
    ('a07', 'AppButton', '가입하기', 0, None, 'same', 'a06'),
    ('a08', 'AppButton', '기존', 0, None, 'other', 'b01'),
    ('a08', 'AppTextLink', '다른', 0, None, 'same', 'a01'),
    ('a09', 'AppButton', '로그인', 0, None, 'other', 'b01'),
    ('a09', 'AppTextLink', '회원가입', 0, None, 'same', 'a03'),
    ('a09', 'SocialIconButton', '', 0, '카카오 → 약관 동의(신규) · Google → [2] 01 홈(기존)', 'same', 'a03'),
    ('b01', 'AppIconBox', '', 0, '알림 (준비 중 안내)', 'stay', None),
    ('b01', 'HomeCourseCard', 'D-', 0, None, 'other', 'e16'),
    ('b01', 'HomeCourseCard', '더 보기', 0, None, 'other', 'e01'),
    ('b01', 'HomeQuickActions', '', 0, '장소 저장 → [5] 01 장소 추가 · 코스 만들기 → [6] 02 1/4 정보', 'other', 'e02'),
    ('b01', 'SectionCard', '', 0, None, 'other', 'c01'),
    ('b01', 'SectionCard', '', 1, None, 'other', 'c01'),
    ('b01', 'DividedRows', '', 0, '지역 줄 → [3] 01 저장됨', 'other', 'c01'),
    ('b01', 'DividedRows', '', 1, '코스 만들기 → [6] 02 1/4 정보 (그 지역 장소로)', 'other', 'e02'),
    ('b01', 'RecentSavedStrip', '', 0, None, 'other', 'c04'),
    ('b02', 'HomeCourseCard', 'D-', 0, None, 'other', 'e16'),
    ('b02', 'HomeCourseCard', '더 보기', 0, None, 'other', 'e01'),
    ('b02', 'HomeQuickActions', '', 0, '장소 저장 → [5] 01 장소 추가 · 코스 만들기 → [6] 02 1/4 정보', 'other', 'e02'),
    ('b02', 'SectionCard', '', 0, None, 'other', 'c01'),
    ('b02', 'SectionCard', '', 1, None, 'other', 'c01'),
    ('b02', 'DividedRows', '', 0, '지역 줄 → [3] 01 저장됨', 'other', 'c01'),
    ('b02', 'DividedRows', '', 1, '코스 만들기 → [6] 02 1/4 정보 (그 지역 장소로)', 'other', 'e02'),
    ('b02', 'RecentSavedStrip', '', 0, None, 'other', 'c04'),
    ('c01', 'PageTitleHeader', '지도', 0, None, 'other', 'c11'),
    ('c01', 'SegmentedTabs', '보관함', 0, None, 'other', 'c07'),
    ('c01', 'SegmentedTabs', 'AI', 0, '같은 화면 안 변화 (AI 추천 탭)', 'stay', None),
    ('c01', 'SectionCard', '필터', 0, None, 'same', 'c02'),
    ('c01', 'SavedPlaceRow', '', 0, None, 'same', 'c04'),
    ('c02', 'DeepLinkCoordinator', '', 0, '카테고리 여러 개 고르기', 'stay', None),
    ('c02', 'SelectCheckbox', '', 0, '체크 · 해제', 'stay', None),
    ('c02', 'AppButton', '보기', 0, None, 'same', 'c03'),
    ('c02', 'AppButton', '', 0, '초기화', 'stay', None),
    ('c03', 'SavedPlaceRow', '', 0, None, 'same', 'c04'),
    ('c04', 'PlainHeader', '공유', 0, '공유 시트', 'stay', None),
    ('c04', 'AppButton', '저장됨', 0, '저장 해제 · 스낵바 되돌리기', 'stay', None),
    ('c04', 'DividedRows', '카카오맵', 0, '카카오맵 열기 (외부)', 'stay', None),
    ('c04', 'PlaceDetail', '', 0, '카카오맵 열기 (외부)', 'stay', None),
    ('c04', 'AppButton', '이', 0, None, 'other', 'e02'),
    ('c05', 'SectionCard', '변경', 0, None, 'same', 'c06'),
    ('c05', 'AppButton', '이', 0, None, 'other', 'e02'),
    ('c06', 'DeepLinkCoordinator', '', 0, '보관함 고르기', 'stay', None),
    ('c06', 'AppButton', '', 0, '보관함 변경 · 스낵바', 'stay', None),
    ('c07', 'PageTitleHeader', '지도', 0, None, 'same', 'c11'),
    ('c07', 'SegmentedTabs', '전체', 0, None, 'other', 'c01'),
    ('c07', 'HeaderTextButton', '새', 0, None, 'same', 'c09'),
    ('c07', 'AllPlacesList', '', 0, None, 'other', 'c01'),
    ('c07', 'CollectionRow', '', 0, None, 'same', 'c08'),
    ('c08', 'AppButton', '지도', 0, None, 'same', 'c11'),
    ('c08', 'SectionHeader', '', 0, '저장한 장소에서 추가 (시트)', 'stay', None),
    ('c08', 'AppCard', '', 0, None, 'other', 'c04'),
    ('c08', 'AppButton', '이', 0, None, 'other', 'e02'),
    ('c10', 'AppButton', '', 0, '저장한 장소에서 추가 · 링크로 장소 찾기 → [5] 01', 'other', 'd01'),
    ('c11', 'SavedMapPage', '목록', 0, '세로 목록으로 올라와요', 'stay', None),
    ('c11', 'PreviewMap', '', 0, '핀 → 장소 카드', 'stay', None),
    ('d01', 'LinkInputPage', '지도에서', 0, None, 'same', 'd07'),
    ('d01', 'SectionCard', '', 0, None, 'other', 'c01'),
    ('d01', 'DividedRows', '', 0, None, 'other', 'c04'),
    ('d03', 'ExtractedPlace', '보관함', 0, None, 'same', 'd04'),
    ('d03', 'AppButton', '저장', 0, None, 'same', 'd05'),
    ('d04', 'DeepLinkCoordinator', '', 0, '보관함 고르기 · 새 보관함', 'stay', None),
    ('d04', 'AppButton', '', 0, '확인 → 03 찾은 장소 (고른 보관함 표시)', 'same', 'd03'),
    ('e03', 'AppButton', '', 0, '출발 시간 확정 → 04 1/4 정보 · 입력 뒤', 'same', 'e04'),
    ('e03', 'DeepLinkCoordinator', '', 0, '시간 고르기', 'stay', None),
    ('d05', 'AppShell', '보기', 0, None, 'other', 'c04'),
    ('d05', 'AppButton', '완료', 0, None, 'same', 'd01'),
    ('d06', 'AppButton', '다른', 0, None, 'same', 'd01'),
    ('e01', 'PageTitleHeader', '', 0, None, 'same', 'e02'),
    ('e01', 'SegmentedTabs', '함께', 0, None, 'other', 'e19'),
    ('e01', 'SectionCard', '', 0, None, 'other', 'e16'),
    ('e01', 'AppTextLink', '코스', 0, None, 'same', 'e02'),
    ('e01', 'CourseSummaryCard', '', 0, None, 'other', 'e16'),
    ('e02', 'AppCard', '출발', 0, None, 'same', 'e03'),
    ('e04', 'AppButton', '다음', 0, None, 'same', 'e05'),
    ('e05', 'AppButton', '다음', 0, '혼자 → 3/4 장소', 'same', 'e09'),
    ('e05', 'CompanionPanel', '', 0, '혼자 · 함께 고르기 → 함께 가요: 02 2/4 동행', 'same', 'e06'),
    ('e06', 'SectionCard', '초대', 0, None, 'same', 'e07'),
    ('e06', 'DividedRows', '', 0, '기존 파티 고르기', 'same', 'e08'),
    ('e06', 'AppButton', '다음', 0, None, 'same', 'e09'),
    ('e08', 'AppButton', '다음', 0, None, 'same', 'e09'),
    ('e09', 'MapPlacePicker', '목록', 0, None, 'same', 'e10'),
    ('e10', 'AppButton', '', 0, None, 'same', 'e11'),
    ('e11', 'AppButton', '추천', 0, '추천 취소 → 3/4 장소', 'same', 'e10'),
    ('e12', 'CourseEditButton', '편집', 0, None, 'other', 'e17'),
    ('e12', 'AppButton', '다시', 0, 'AI 자리만 다시 추천 (되돌리기)', 'stay', None),
    ('e12', 'AppButton', '코스', 0, '파티 코스 → 14 파티원 알림 시트 · 혼자 → 15 코스 상세', 'same', 'e14'),
    ('e13', 'CourseEditButton', '편집', 0, None, 'other', 'e17'),
    ('e13', 'AppButton', '다시', 0, 'AI 자리만 다시 추천 (되돌리기)', 'stay', None),
    ('e13', 'AppButton', '코스', 0, '파티 코스 → 14 파티원 알림 시트 · 혼자 → 15 코스 상세', 'same', 'e14'),
    ('e14', 'CourseEditButton', '편집', 0, None, 'other', 'e17'),
    ('e15', 'CourseEditButton', '편집', 0, None, 'other', 'e17'),
    ('e16', 'CourseEditButton', '편집', 0, None, 'same', 'e17'),
    ('e17', 'AppButton', '저장', 0, '저장 → 01 코스 상세', 'same', 'e16'),
    ('e17', 'AppButton', '다시', 0, 'AI 자리만 다시 추천', 'stay', None),
    ('e18', 'CourseEditPlace', '되돌리기', 0, '빼기 되돌리기', 'stay', None),
    ('e18', 'AppButton', '저장', 0, '저장 → 01 코스 상세', 'same', 'e16'),
    ('e19', 'SegmentedTabs', '내', 0, None, 'other', 'e01'),
    ('e19', 'HomeCourseCard', '', 0, None, 'same', 'e16'),
    ('e19', 'CourseSummaryCard', '', 0, None, 'same', 'e16'),
    ('f01', 'AppButton', '코스에', 0, None, 'other', 'e19'),
    ('f01', 'AppTextLink', '참여하지', 0, None, 'other', 'b01'),
    ('f02', 'AppButton', '홈', 0, None, 'other', 'b01'),
    ('g01', 'AppTextLink', '', 0, None, 'same', 'g02'),
    ('g01', 'SectionCard', '추천하지', 0, None, 'same', 'g03'),
    ('g01', 'MyPage', '로그아웃', 0, None, 'same', 'g04'),
    ('g01', 'MyPage', '프로필', 0, '프로필 수정 (준비 중 안내)', 'stay', None),
    ('g01', 'DividedRows', '', 0, '설정 행 (알림 · 개인정보 · 도움말) 준비 중 안내', 'stay', None),
    ('g02', 'AppCard', '추천하지', 0, None, 'same', 'g03'),
    ('g02', 'AppButton', '', 0, None, 'other', 'c01'),
    ('g04', 'AppButton', '', 0, '취소 → 01 마이 · 로그아웃 → [1] 01 로그인', 'other', 'a01'),
]

# 말 없는 화살표(눌러서 가지 않는 이동) · 스크롤 등: (출발, 도착, 이름, 번호 줄로 넣을지)
FREE = [
    ('a01', 'a02', '소셜 로그인 오류', False),
    ('a01', 'a08', '이미 가입된 이메일', False),
    ('a01', 'a09', '아이디 로그인 실패', False),
    ('b01', 'b02', '스크롤', True),
    ('c04', 'c05', '스크롤', True),
    ('c09', 'c10', '보관함 만들기', False),
    ('d01', 'd02', '링크 넣고 찾기', False),
    ('d01', 'd06', '비공개 링크', False),
    ('d02', 'd03', '분석 끝', False),
    ('e03', 'e04', '시간 고르기', False),
    ('e06', 'e07', '초대하기', False),
    ('e10', 'e11', '코스 추천받기', False),
    ('e11', 'e12', '추천 완료', False),
    ('e12', 'e13', '스크롤', True),
    ('e14', 'e15', '나중에', False),
    ('e17', 'e18', '이번만 빼기', False),
    ('e16', 'e17', '편집', False),
]

GENERIC = {
    '뒤로': '이전 화면으로 돌아가요',
    '닫기': '이전 화면으로 돌아가요',
}

CIRC = '①②③④⑤⑥⑦⑧⑨⑩⑪⑫⑬⑭⑮⑯⑰⑱⑲⑳'


def pick(sid, tap, nth_counter):
    """규칙에서 이 누르는 곳의 결과를 찾는다"""
    cmp0 = (tap['cmp'][:1] or [''])[0]
    lab = (tap.get('label', '') + ' ' + tap.get('tip', ''))
    for r in R:
        if r[0] != sid:
            continue
        if not cmp0.startswith(r[1]):
            continue
        if r[2] and r[2] not in lab:
            continue
        key = (sid, r[1], r[2])
        # nth: 같은 (cmp, 포함어) 조합에서 몇 번째 매칭인지
        c = nth_counter.get((sid, r[1], r[2], r[3]), 0)
        return r, key
    return None, None


def build():
    out = []
    for sec, title, sub, entry, scr in SECTIONS:
        screens = []
        edges = []
        for i, (sid, t) in enumerate(scr):
            name = ALL.get(sid)
            if not name:
                print('missing', sid)
                continue
            d, taps = T.process(name)
            hs, rows = [], []
            used_nth = {}
            for k, tp in enumerate(taps, 1):
                cmp0 = (tp['cmp'][:1] or [''])[0]
                disp = '시트' if cmp0 == 'DeepLinkCoordinator' else cmp0
                lab = tp.get('label', '')
                if cmp0 == 'AppBottomNav':
                    line1 = '탭 · AppBottomNav 하단 탭'
                    line2 = '→ 홈 [2] 01 · 저장됨 [3] 01 · 코스 [6] 01 · 장소 추가 [5] 01 · 마이 [9] 01'
                    rows.append([k, line1, line2, 'other'])
                else:
                    # n번째 규칙: 이 누르는 곳에 맞는 규칙들 중, 같은 (cmp, 포함어) 조합에서 몇 번째인지로 고른다
                    res, kind, tgt = None, 'stay', None
                    labt = lab + ' ' + tp.get('tip', '')
                    cands = [r for r in R if r[0] == sid and cmp0.startswith(r[1]) and (not r[2] or r[2] in labt)]
                    matched = None
                    for r in cands:
                        if used_nth.get((r[1], r[2]), 0) == r[3]:
                            matched = r
                            break
                    for key in {(r[1], r[2]) for r in cands}:
                        used_nth[key] = used_nth.get(key, 0) + 1
                    short = lab.replace('\n', ' ')
                    short = short[:16] + ('…' if len(short) > 16 else '')
                    if tp.get('group'):
                        line1 = f"탭 · {disp} 항목" + (f" ({tp.get('n')}개)" if tp.get('n') else '')
                    else:
                        line1 = f"탭 · {disp}" + (f" '{short}'" if short else (f" {tp.get('tip','')}" if tp.get('tip') else ''))
                    if matched:
                        _, _, _, _, txt, kind, tgt = matched
                        if tgt:
                            tt = ref(tgt, same=(kind == 'same'))
                            res = (txt if txt.startswith('→') or '→' in txt else f"→ {txt}") if txt else f"→ {tt}"
                            if txt and tgt and kind == 'same' and tt not in txt:
                                pass
                            if kind == 'same' and tgt in NAMES and NAMES[tgt][0] == sec:
                                edges.append([sid, tgt, short or cmp0, k])
                        else:
                            res = f"{txt}"
                    else:
                        tip = tp.get('tip', '')
                        if tip in GENERIC or (lab in GENERIC):
                            res, kind = GENERIC.get(tip) or GENERIC.get(lab), 'back'
                        else:
                            res, kind = '같은 화면 안 변화', 'stay'
                    rows.append([k, line1, res, kind])
                hs.append([k, round(tp['x']), round(tp['y']), round(tp['w']), round(tp['h'])])
            # 자유 화살표의 번호 줄 (스크롤)
            n_after = len(rows)
            for (a, b, nm, numbered) in FREE:
                if a == sid and numbered:
                    n_after += 1
                    rows.append([n_after, f"스크롤 · 화면 아래로" if nm == '스크롤' else nm, f"→ {ref(b, same=True)}", 'same'])
                    edges.append([a, b, '스크롤', n_after])
            screens.append({'id': sid, 'name': name, 'title': t, 'num': i + 1, 'hs': hs, 'rows': rows})
        for (a, b, nm, numbered) in FREE:
            if a in [s['id'] for s in screens] and b in [s['id'] for s in screens] and not numbered:
                edges.append([a, b, nm, 0])
        # 중복 제거
        seen, uniq = set(), []
        for e in edges:
            key = (e[0], e[1])
            if key in seen:
                continue
            seen.add(key)
            uniq.append(e)
        out.append({'sec': sec, 'title': title, 'sub': sub, 'entry': entry, 'screens': screens, 'edges': uniq})
    return out


if __name__ == '__main__':
    data = build()
    json.dump(data, open('layout.json', 'w', encoding='utf-8'), ensure_ascii=False)
    for s in data:
        print(s['sec'], s['title'], len(s['screens']), 'screens', len(s['edges']), 'edges', sum(len(x['rows']) for x in s['screens']), 'rows')
