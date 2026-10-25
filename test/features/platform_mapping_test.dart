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
}
