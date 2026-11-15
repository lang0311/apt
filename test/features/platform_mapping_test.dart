import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apt/core/network/api_client.dart';
import 'package:apt/features/course/domain/course_models.dart';
import 'package:apt/features/platform/data/platform_client.dart';
import 'package:apt/features/platform/data/platform_repositories.dart';
import 'package:apt/features/saved/domain/saved_models.dart';

void main() {
  test(
    'Map coordinates and canonical keys are preserved without inventing ratings',
    () {
      final c = PlatformClient(ApiClient(Dio()));
      final p = c.place({
        'id': 'provider-id',
        'key': 'canonical',
        'name': '장소',
        'address': '서울 마포구',
        'lat': 37.55,
        'lon': 126.92,
        'category': '음식점 > 카페',
        'selection_token': 'signed',
      });
      expect(p.id, 'canonical');
      expect(p.location!.lng, 126.92);
      expect(p.rating, isNull);
      expect(c.places['canonical']!['selection_token'], 'signed');
    },
  );
  test('Course stop source is mapped and confirmed courses are read-only', () {
    final c = PlatformClient(ApiClient(Dio()));
    final course = c.course({
      'id': 'course',
      'status': 'confirmed',
      'party_id': null,
      'itinerary': [
        {'key': 'a', 'name': '필수', 'address': '서울', 'saved': true},
        {
          'key': 'b',
          'name': '추천',
          'address': '서울',
          'saved': false,
          'description': '선정 이유',
        },
      ],
    });
    expect(course.stops.first.isAi, isFalse);
    expect(course.stops.last.aiReason, '선정 이유');
    expect(course.canEdit, isFalse);
    expect(course.stops.last.nextLeg, isNull);
  });
  test('장소의 태그 · 전화 · 카카오맵 주소를 넘긴다 (없거나 빈 값은 비운다)', () {
    final c = PlatformClient(ApiClient(Dio()));
    final full = c.place({
      'key': 'k1',
      'name': 'KT&G상상마당 홍대',
      'address': '서울 마포구 서교동 367-5',
      'phone': '02-330-6200',
      'place_url': 'http://place.map.kakao.com/1',
      'attribute_profile': {
        'tags': [
          {'tag': '예술', 'dimension': 'interest_theme'},
          {'tag': '공연 감상', 'dimension': 'activity'},
          {'tag': '예술', 'dimension': 'interest_theme'},
        ],
      },
    });
    expect(full.keywords, ['예술', '공연 감상']);
    expect(full.phone, '02-330-6200');
    expect(full.mapUrl, 'http://place.map.kakao.com/1');

    final bare = c.place({'key': 'k2', 'name': '마포새빛문화숲', 'address': '서울', 'phone': '', 'place_url': 'javascript:alert(1)'});
    expect(bare.keywords, isEmpty);
    expect(bare.phone, isNull);
    expect(bare.mapUrl, isNull);
  });
  test('추천 일정의 temporal을 넘기고, 같은 장소를 temporal 없이 다시 받아도 유지한다 (서버 API 1번)', () {
    final c = PlatformClient(ApiClient(Dio()));
    final popup = c.place({
      'key': 'k3',
      'name': '무신사 스페이스 서울숲',
      'address': '서울 성동구 성수동1가',
      'temporal': {'kind': 'popup', 'start_date': '2026-11-11', 'end_date': '2026-11-29', 'checked_on': '2026-11-15'},
    });
    expect(popup.timing?.end, DateTime(2026, 11, 29));
    expect(c.place({'key': 'k3', 'name': '무신사 스페이스 서울숲', 'address': '서울 성동구 성수동1가'}).timing?.end, DateTime(2026, 11, 29));

    final plain = c.place({'key': 'k4', 'name': 'KT&G상상마당 홍대', 'address': '서울', 'temporal': {'kind': 'place', 'start_date': '', 'end_date': ''}});
    expect(plain.timing, isNull);
  });

  test('빈 추천 이유는 null로 넘긴다 (시트에 추천 이유 보기가 안 뜨게)', () {
    final c = PlatformClient(ApiClient(Dio()));
    final course = c.course({
      'id': 'course',
      'status': 'draft',
      'party_id': null,
      'itinerary': [
        {'key': 'a', 'name': '빈 이유', 'address': '서울', 'saved': false, 'description': ''},
        {'key': 'b', 'name': '공백 이유', 'address': '서울', 'saved': false, 'description': '  '},
        {'key': 'c', 'name': '이유 없음', 'address': '서울', 'saved': false},
      ],
    });
    for (final stop in course.stops) {
      expect(stop.isAi, isTrue);
      expect(stop.aiReason, isNull);
    }
  });
  test('Selected place tokens are sent unchanged', () async {
    final c = PlatformClient(ApiClient(Dio()));
    c.place({
      'id': 'a',
      'name': '장소',
      'address': '서울',
      'selection_token': 'signed',
    });
    expect(await c.token('a'), 'signed');
  });
  test('Social login is never simulated in actual backend mode', () async {
    final c = PlatformClient(ApiClient(Dio()));
    expect(PlatformSavedRepository(c).fetchCollections(), completion(isEmpty));
  });

  test('홈 다가오는 코스는 저장(확정)한 코스 중 오늘 이후 · 날짜 없음만', () {
    final today = DateTime(2026, 10, 26);
    Json course(String status, String? date) => {'status': status, 'date': date};
    expect(PlatformCourseRepository.isUpcoming(course('confirmed', '2026-10-29T00:00:00.000'), today), isTrue);
    expect(PlatformCourseRepository.isUpcoming(course('confirmed', '2026-10-26T00:00:00.000'), today), isTrue, reason: '오늘');
    expect(PlatformCourseRepository.isUpcoming(course('confirmed', null), today), isTrue, reason: '날짜 없음');
    expect(PlatformCourseRepository.isUpcoming(course('confirmed', '2026-10-20'), today), isFalse, reason: '지난 코스');
    expect(PlatformCourseRepository.isUpcoming(course('draft', '2026-10-29'), today), isFalse, reason: '저장 안 한 추천 결과');
  });

  test('최근 저장한 곳은 서버 저장 시각 최신순, 시각 없는 곳은 뺀다', () {
    final repo = PlatformExtractionRepository(PlatformClient(ApiClient(Dio())));
    Json place(String key, String? at) => {'key': key, 'name': key, 'address': '서울', 'saved_at': at};
    final recent = repo.recentFrom([
      place('a', '2026-10-24T03:00:00Z'),
      place('b', '2026-10-26T01:00:00Z'),
      place('c', null),
      place('d', '2026-10-25T09:00:00Z'),
    ], limit: 2);
    expect(recent.map((r) => r.place.id), ['b', 'd']);
    expect(recent.every((r) => r.place.isSaved), isTrue);
  });
  test('Server job stages collapse into the four screen stages', () {
    RecommendationStage? m(String s) => PlatformCourseRepository.recommendationStage(s);
    expect(m('preparing'), RecommendationStage.findCandidates);
    expect(m('refilling'), RecommendationStage.findCandidates);
    expect(m('verifying'), RecommendationStage.checkPlaces);
    expect(m('balancing_group'), RecommendationStage.matchTaste);
    expect(m('reviewing'), RecommendationStage.organize);
    expect(m('queued'), isNull);
  });
  test('파티 이름은 만든 사람 이름으로, 서버 길이 제한 60자 안', () {
    expect(partyNameFor('김랑'), '김랑님의 파티');
    expect(partyNameFor('  '), '새 파티');
    expect(partyNameFor('가' * 60).length, 60);
  });
  test('파티장은 GET /me의 owner로 판단한다 — 파티원이면 isOwner가 false', () async {
    final c = _FakePlatform({
      '/me': {
        'user': {'id': 'me', 'name': '김랑'},
        'places': [],
        'parties': [
          {'id': 'mine', 'name': '김랑님의 파티', 'owner': 'me', 'members': _members},
          {'id': 'joined', 'name': '지민님의 파티', 'owner': 'u2', 'members': _members},
        ],
      },
      '/parties/joined': {'members': _members},
    });
    final repo = PlatformPartyRepository(c);
    // 파티 상세에는 owner가 없어서, 모르면 /me를 먼저 받아 온다
    expect((await repo.fetchParty('joined')).isOwner, isFalse);
    expect(c.calls, ['/me', '/parties/joined']);
    final parties = await repo.fetchMyParties();
    expect({for (final p in parties) p.id: p.isOwner}, {'mine': true, 'joined': false});
  });
  test('반영한 취향 단어: 관심 주제 + 업종, 넓은 지도 분류 · 경로 · 분위기 단어는 빼고 서버 순서대로 (07 D46)', () {
    final taste = PlatformClient.appliedTaste({
      'summary': '선택·저장한 장소에서는 미식, 자연, 카페, 한식, 여행 관련 관심이 나타납니다.',
      'group_size': 1,
      'keywords': [
        {'category': '미식', 'dimension': 'interest_theme'},
        {'category': '자연', 'dimension': 'interest_theme'},
        {'category': '아늑한', 'dimension': 'atmosphere'},
        {'category': '카페', 'dimension': 'category'},
        {'category': '한식', 'dimension': 'category'},
        {'category': '여행', 'dimension': 'category'},
        {'category': '음식점 > 한식', 'dimension': 'category'},
      ],
    })!;
    expect(taste.words, ['미식', '자연', '카페', '한식']);
    expect(taste.memberCount, 1);
    expect(PlatformClient.appliedTaste({'keywords': [{'category': '여행'}]}), isNull);
    expect(PlatformClient.appliedTaste(null), isNull);
  });
  test('파티 코스: 2명 이상이 공유한 단어만, 없으면 단어 없이 인원만, 취향이 아예 없으면 줄 없음 (07 D46)', () {
    // 2026-11-13 3명 파티 실제 응답의 keywords
    final taste = PlatformClient.appliedTaste({
      'group_size': 3,
      'keywords': [
        {'category': '미식', 'dimension': 'interest_theme', 'shared_by': 2},
        {'category': '자연', 'dimension': 'interest_theme', 'shared_by': 0},
        {'category': '역사', 'dimension': 'interest_theme', 'shared_by': 0},
        {'category': '식물', 'dimension': 'specific_interest', 'shared_by': 0},
        {'category': '카페', 'dimension': 'category', 'shared_by': 3},
      ],
    })!;
    expect(taste.words, ['미식', '카페']);
    expect(taste.memberCount, 3);
    final plain = PlatformClient.appliedTaste({
      'group_size': 2,
      'keywords': [
        {'category': '자연', 'dimension': 'interest_theme', 'shared_by': 1},
        {'category': '공원', 'dimension': 'category'},
      ],
    })!;
    expect(plain.words, isEmpty);
    expect(plain.memberCount, 2);
    // 저장 기록이 없는 파티 (서버 테스트 test_recordless_party_…: keywords [])
    expect(PlatformClient.appliedTaste({'group_size': 2, 'keywords': []}), isNull);
  });
  test('파티 코스: 장소마다 맞는 파티원을 이름으로 일정과 맞추고, 반영되지 못한 파티원을 모은다 (07 D46)', () {
    // 2026-11-13 3명 파티 실제 응답 모양 (id는 줄임)
    final itinerary = [
      {'key': 'k-forest', 'name': '경의선숲길', 'saved': true},
      {'key': 'k-cafe', 'name': '카페공명 연남점', 'saved': false},
      {'key': 'k-hansik', 'name': '진청유점', 'saved': false},
      {'key': 'k-bar', 'name': '잊힐리야 연남', 'saved': false},
    ];
    final taste = PlatformClient.appliedTaste({
      'group_size': 3,
      'keywords': [
        {'category': '미식', 'dimension': 'interest_theme', 'shared_by': 2},
      ],
      'group_blend': {
        'per_user': {
          'jimin': {'status': 'evaluated', 'represented': true, 'strong_match_places': ['카페공명 연남점', '잊힐리야 연남']},
          'test': {'status': 'evaluated', 'represented': true, 'strong_match_places': ['진청유점']},
          'youngseo': {'status': 'evaluated', 'represented': true, 'strong_match_places': ['카페공명 연남점']},
        },
      },
    }, itinerary: itinerary)!;
    expect(taste.matches, {
      'k-cafe': ['jimin', 'youngseo'],
      'k-bar': ['jimin'],
      'k-hansik': ['test'],
    });
    expect(taste.gaps, isEmpty);
    expect(taste.hasDetail, isTrue);

    final gapped = PlatformClient.appliedTaste({
      'group_size': 3,
      'keywords': [
        {'category': '미식', 'dimension': 'interest_theme', 'shared_by': 2},
      ],
      'group_blend': {
        'per_user': {
          'a': {'status': 'evaluated', 'represented': false, 'strong_match_places': []},
          'b': {'status': 'insufficient_history', 'represented': null},
          // 같은 이름이 일정에 두 번 있으면 어느 쪽인지 몰라 뺀다 · 일정에 없는 이름도 뺀다
          'c': {'status': 'evaluated', 'represented': true, 'strong_match_places': ['스타벅스', '없는 곳']},
        },
      },
    }, itinerary: [
      {'key': 's1', 'name': '스타벅스'},
      {'key': 's2', 'name': '스타벅스'},
    ])!;
    expect(gapped.matches, isEmpty);
    expect([for (final g in gapped.gaps) (g.memberId, g.noHistory)], [('a', false), ('b', true)]);

    // 혼자 코스는 group_blend를 보지 않는다
    final solo = PlatformClient.appliedTaste({
      'group_size': 1,
      'keywords': [{'category': '자연', 'dimension': 'interest_theme'}],
      'group_blend': null,
    }, itinerary: itinerary)!;
    expect(solo.hasDetail, isFalse);
  });
  test('추천 결과와 저장한 코스 모두 반영한 취향을 읽는다', () {
    final c = PlatformClient(ApiClient(Dio()));
    final course = c.course({
      'id': 'k',
      'status': 'confirmed',
      'party_id': null,
      'itinerary': [],
      'taste_profile': {
        'group_size': 1,
        'keywords': [
          {'category': '자연', 'dimension': 'interest_theme'},
        ],
      },
    });
    expect(course.taste!.words, ['자연']);
  });
  test('코스로 들어온 저장 장소: AI 추천은 따로, 직접 고른 곳 · 직접 저장은 카테고리와 개수에 (07 D44)', () async {
    final c = _FakePlatform({
      '/me': {
        'user': {'id': 'me', 'name': '김랑'},
        'parties': [],
        'places': [
          {'key': 'a', 'name': '직접', 'category': '음식점 > 한식', 'action_type': 'direct_save'},
          {'key': 'b', 'name': 'AI', 'category': '여행 > 공원', 'action_type': 'course_confirmed'},
          {'key': 'c', 'name': '고른 곳', 'category': '음식점 > 카페', 'action_type': 'course_confirmed'},
          {'key': 'd', 'name': '코스 모름', 'category': '음식점 > 카페', 'action_type': 'course_confirmed'},
        ],
      },
      '/courses': [
        {
          'id': 'x',
          'title': '연남 산책',
          'status': 'confirmed',
          'itinerary': [
            {'key': 'c', 'saved': true},
            {'key': 'b', 'saved': false},
          ],
        },
        // 저장하지 않은 추천 결과(초안)는 보지 않는다
        {
          'id': 'y',
          'title': '초안',
          'status': 'draft',
          'itinerary': [
            {'key': 'd', 'saved': false},
          ],
        },
      ],
    });
    final repo = PlatformSavedRepository(c);
    final mine = await repo.fetchSavedPlaces(const SavedPlaceQuery());
    expect([for (final i in mine) i.place.name], ['직접', '고른 곳']);
    final ai = await repo.fetchAiSavedPlaces();
    expect({for (final i in ai) i.place.name: i.recommendedIn}, {'AI': '연남 산책', '코스 모름': null});
    final summary = await repo.fetchSummary();
    expect(summary.totalCount, 2);
    expect({for (final cat in summary.categories) cat.label: cat.count}, {'한식': 1, '카페': 1});
    // 코스 목록은 같은 장소 목록이면 한 번만 받는다
    expect(c.calls.where((path) => path == '/courses'), hasLength(1));
  });
}

const _members = [
  {'id': 'me', 'name': '김랑', 'login': 'rang'},
  {'id': 'u2', 'name': '지민', 'login': 'jimin'},
];

class _FakePlatform extends PlatformClient {
  _FakePlatform(this.responses) : super(ApiClient(Dio()));
  final Map<String, dynamic> responses;
  final calls = <String>[];

  @override
  Future<dynamic> get(String path, [Map<String, dynamic>? query]) async {
    calls.add(path);
    return responses[path];
  }
}
