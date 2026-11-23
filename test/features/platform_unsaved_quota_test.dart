import 'dart:convert';
import 'dart:typed_data';

import 'package:apt/core/error/app_failure.dart';
import 'package:apt/core/models/geo_point.dart';
import 'package:apt/core/network/api_client.dart';
import 'package:apt/features/course/data/unsaved_recommendation_storage.dart';
import 'package:apt/features/course/domain/course_draft.dart';
import 'package:apt/features/course/presentation/widgets/recommendation_quota.dart';
import 'package:apt/features/place/domain/place_search_repository.dart';
import 'package:apt/features/platform/data/platform_client.dart';
import 'package:apt/features/platform/data/platform_repositories.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// 경로별로 정해 둔 응답을 돌려주고 요청을 기록한다
class _Server implements HttpClientAdapter {
  _Server(this.routes);
  final Map<String, Object? Function(RequestOptions)> routes;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final handler = routes['${options.method} ${options.path}'];
    final body = handler?.call(options);
    return ResponseBody.fromString(jsonEncode(body ?? {'detail': '없음'}), handler == null ? 404 : 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

/// 기기 저장소 대신 메모리에 둔다
class _MemoryUnsaved extends UnsavedRecommendationStorage {
  ({String courseId, DateTime receivedAt})? value;
  bool dismissed = false;

  @override
  Future<({String courseId, DateTime receivedAt})?> read(String userId) async => dismissed ? null : value;
  @override
  Future<void> remember(String userId, String courseId, DateTime receivedAt) async {
    value = (courseId: courseId, receivedAt: receivedAt);
    dismissed = false;
  }

  @override
  Future<void> dismiss(String userId, String courseId) async => dismissed = true;
  @override
  Future<void> clear(String userId) async => value = null;
}

const _me = {
  'user': {'id': 'u1'},
  'parties': [],
  'places': [],
};

Map<String, dynamic> _course({String status = 'draft', String owner = 'u1', String? date}) => {
  'id': 'c1',
  'status': status,
  'owner': owner,
  'revision': 3,
  'date': date,
  'itinerary': [
    {'key': 'k1', 'name': '어니언 성수', 'address': '서울 성동구 성수동2가 277-135', 'saved': true},
    {
      'key': 'k2',
      'name': '대림창고',
      'address': '서울 성동구 성수이로 78',
      'description': '전시가 열려요',
      'web_evidence': [
        {'url': 'https://www.korean.visitseoul.net/a', 'quote': '사진전', 'published': '2026-11-02'},
        {'url': 'https://www.korean.visitseoul.net/a', 'quote': '같은 주소'},
        {'url': '', 'quote': '주소 없음'},
      ],
    },
  ],
};

void main() {
  group('저장하지 않은 추천 (13번)', () {
    late _MemoryUnsaved storage;
    setUp(() => storage = _MemoryUnsaved());

    PlatformCourseRepository repoWith(Map<String, Object? Function(RequestOptions)> routes) =>
        PlatformCourseRepository(PlatformClient(ApiClient(Dio()..httpClientAdapter = _Server(routes))), storage);

    test('기억한 초안이 아직 초안이면 지역 이름 · 받은 시각과 함께 돌려준다', () async {
      final at = DateTime(2026, 11, 23, 10);
      storage.value = (courseId: 'c1', receivedAt: at);
      final repo = repoWith({'GET /me': (_) => _me, 'GET /courses/c1': (_) => _course()});

      final unsaved = await repo.fetchUnsavedRecommendation();

      expect(unsaved, isNotNull);
      expect(unsaved!.title, '성동구 코스');
      expect(unsaved.receivedAt, at);
      expect(unsaved.course.stops, hasLength(2));
    });

    test('저장(확정)했거나 서버에서 사라졌으면 안내하지 않고 기억도 지운다', () async {
      storage.value = (courseId: 'c1', receivedAt: DateTime(2026, 11, 23));
      final confirmed = repoWith({'GET /me': (_) => _me, 'GET /courses/c1': (_) => _course(status: 'confirmed')});
      expect(await confirmed.fetchUnsavedRecommendation(), isNull);
      expect(storage.value, isNull);

      storage.value = (courseId: 'c1', receivedAt: DateTime(2026, 11, 23));
      final gone = repoWith({'GET /me': (_) => _me});
      expect(await gone.fetchUnsavedRecommendation(), isNull);
      expect(storage.value, isNull);
    });

    test('날짜가 지난 초안은 띄우지 않는다', () async {
      storage.value = (courseId: 'c1', receivedAt: DateTime(2026, 11, 1));
      final repo = repoWith({'GET /me': (_) => _me, 'GET /courses/c1': (_) => _course(date: '2020-01-01')});
      expect(await repo.fetchUnsavedRecommendation(), isNull);
    });

    test('닫으면 같은 초안은 다시 띄우지 않는다', () async {
      storage.value = (courseId: 'c1', receivedAt: DateTime(2026, 11, 23));
      final repo = repoWith({'GET /me': (_) => _me, 'GET /courses/c1': (_) => _course()});
      await repo.fetchUnsavedRecommendation();
      await repo.dismissUnsavedRecommendation('c1');
      expect(await repo.fetchUnsavedRecommendation(), isNull);
    });
  });

  group('오늘 추천 한도 (12번)', () {
    PlatformCourseRepository repoWith(Map<String, Object?> usage) => PlatformCourseRepository(
      PlatformClient(ApiClient(Dio()..httpClientAdapter = _Server({'GET /me/usage': (_) => usage}))),
      _MemoryUnsaved(),
    );
    final reset = DateTime.utc(2026, 11, 24);
    Map<String, Object?> usage({int calls = 0, double cost = 0}) => {
      'daily_call_limit': 24,
      'daily_usd_limit': 10,
      'reset_at': reset.millisecondsSinceEpoch ~/ 1000,
      'call_count': calls,
      'cost_usd': cost,
      'reserved_usd': 0,
    };

    test('호출 수나 비용을 다 쓰면 막고, 초기화 시각을 준다', () async {
      expect((await repoWith(usage(calls: 3)).fetchRecommendationQuota())!.exhausted, isFalse);
      expect((await repoWith(usage(calls: 24)).fetchRecommendationQuota())!.exhausted, isTrue);
      expect((await repoWith(usage(cost: 9.95)).fetchRecommendationQuota())!.exhausted, isTrue);
      expect((await repoWith(usage()).fetchRecommendationQuota())!.resetAt.toUtc(), reset);
    });

    test('추천 중에 서버 한도에 걸리면 QuotaExceededFailure', () async {
      final client = PlatformClient(
        ApiClient(
          Dio()
            ..httpClientAdapter = _Server({
              'GET /jobs': (_) => [],
              'POST /jobs': (_) => {'job_id': 'j1'},
              'GET /jobs/j1': (_) => {'status': 'failed', 'error': '오늘의 추천 호출·예산 한도에 도달했습니다.'},
            }),
        ),
      );
      final repo = PlatformCourseRepository(client, _MemoryUnsaved());
      final place = client.place({'key': 'k1', 'name': '어니언', 'address': '서울 성동구 성수동', 'selection_token': 't'}, saved: true);

      await expectLater(repo.recommend(draft: CourseDraft(places: [place])), throwsA(isA<QuotaExceededFailure>()));
    });

    test('초기화 시각 문구', () {
      final now = DateTime(2026, 11, 23, 15);
      expect(quotaResetLabel(DateTime(2026, 11, 24, 9), now: now), '내일 오전 9시부터 다시 받을 수 있어요');
      expect(quotaResetLabel(DateTime(2026, 11, 23, 21, 30), now: now), '오늘 오후 9시 30분부터 다시 받을 수 있어요');
      expect(quotaResetLabel(DateTime(2026, 11, 24), now: now), '내일 0시부터 다시 받을 수 있어요');
    });
  });

  test('코스 장소 수는 고른 수 이상 6곳 이하, 기본은 고른 수 + 3 (11번)', () {
    final client = PlatformClient(ApiClient(Dio()));
    final places = [for (var i = 0; i < 2; i++) client.place({'key': 'k$i', 'name': '곳$i'})];
    expect(CourseDraft(places: places).coursePlaceCount, 5);
    expect(CourseDraft(places: places, placeCount: 1).coursePlaceCount, 2);
    expect(CourseDraft(places: places, placeCount: 9).coursePlaceCount, 6);
    expect(CourseDraft(places: [...places, ...places, ...places]).coursePlaceCount, 6);
  });

  test('추천에 쓴 글은 주소가 있는 것만, 같은 주소는 한 번만 (2번)', () {
    final stops = PlatformClient(ApiClient(Dio())).stops(_course());
    expect(stops.first.evidence, isEmpty); // 내가 고른 곳
    final evidence = stops.last.evidence;
    expect(evidence, hasLength(1));
    expect(evidence.single.host, 'korean.visitseoul.net');
    expect(evidence.single.quote, '사진전');
    expect(evidence.single.publishedAt, DateTime(2026, 11, 2));
  });

  test('업종 칩은 검색어 없이 지도 가운데와 서버 업종 코드로 찾는다 (10번)', () async {
    final server = _Server({
      'GET /me': (_) => _me,
      'GET /places/search': (_) => {'places': []},
    });
    final repo = PlatformPlaceSearchRepository(PlatformClient(ApiClient(Dio()..httpClientAdapter = server)));

    await repo.search('', near: const GeoPoint(37.54, 127.05), category: PlaceSearchCategory.restaurant);

    final query = server.requests.last.queryParameters;
    expect(query['q'], '');
    expect(query['category'], 'FD6');
    expect(query['lat'], 37.54);
    expect(query['lon'], 127.05);
  });

  test('저장됨은 저장한 시각 최신순, 시각이 없으면 맨 뒤 (14번)', () {
    final rows = [
      {'key': 'a', 'saved_at': '2026-11-01T00:00:00Z'},
      {'key': 'b'},
      {'key': 'c', 'saved_at': '2026-11-20T00:00:00Z'},
    ]..sort(PlatformSavedRepository.bySavedAtDesc);
    expect([for (final r in rows) r['key']], ['c', 'a', 'b']);
  });

  test('칩 결과는 지도 가운데에서 먼 곳을 뺀다 (국외 좌표면 카카오가 반경을 무시함, 10번)', () async {
    final server = _Server({
      'GET /me': (_) => _me,
      'GET /places/search': (_) => {
        'places': [
          {'id': 'near', 'name': '가까운 카페', 'lat': 37.541, 'lon': 127.05},
          {'id': 'far', 'name': '울산 카페', 'lat': 35.53, 'lon': 129.31},
        ],
      },
    });
    final repo = PlatformPlaceSearchRepository(PlatformClient(ApiClient(Dio()..httpClientAdapter = server)));

    final found = await repo.search('', near: const GeoPoint(37.54, 127.05), category: PlaceSearchCategory.cafe);
    expect([for (final p in found) p.id], ['near']);
  });
}
