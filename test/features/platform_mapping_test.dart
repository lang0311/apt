import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apt/core/network/api_client.dart';
import 'package:apt/features/platform/data/platform_client.dart';
import 'package:apt/features/platform/data/platform_repositories.dart';

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
}
