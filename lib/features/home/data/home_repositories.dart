import '../../../core/error/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../../../dev/mock/mock_store.dart';
import '../../place/domain/place.dart';
import '../domain/home_models.dart';
import '../domain/home_repository.dart';

class MockHomeRepository implements HomeRepository {
  MockHomeRepository(this._store);
  final MockStore _store;

  @override
  Future<HomeStats> fetchStats() => _store.behavior.query(
        () => HomeStats(
          savedPlaceCount: _store.savedIds.length,
          activeCourseCount: _store.courses.length,
          recentExtractionCount: 12,
          recentExtractionPeriodLabel: '이번 주',
        ),
        empty: () => const HomeStats(savedPlaceCount: 0, activeCourseCount: 0, recentExtractionCount: 0),
      );

  @override
  Future<List<Place>> fetchTrendingPlaces() => _store.behavior.query(
        () => [for (final id in ['p7', 'p2', 'p8']) _store.placeWithSaved(id)],
        empty: () => const [],
      );
}

// NEEDS BACKEND: 홈 aggregate(저장 장소 수·진행 코스 수·최근 추출 수) / 트렌딩 API
class ApiHomeRepository implements HomeRepository {
  ApiHomeRepository(this._client);
  // ignore: unused_field
  final ApiClient _client;

  static const _f = NotImplementedFailure('홈');

  @override
  Future<HomeStats> fetchStats() async => throw _f;
  @override
  Future<List<Place>> fetchTrendingPlaces() async => throw _f;
}
