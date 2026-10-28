import '../../../core/error/app_failure.dart';
import '../../../core/models/geo_point.dart';
import '../../../core/network/api_client.dart';
import '../../../dev/mock/mock_fixtures.dart';
import '../../../dev/mock/mock_store.dart';
import '../domain/place.dart';
import '../domain/place_search_repository.dart';

/// Mock: 앱 안의 예시 장소에서 이름·업종·주소로 찾는다.
class MockPlaceSearchRepository implements PlaceSearchRepository {
  MockPlaceSearchRepository(this._store);
  final MockStore _store;

  @override
  Future<List<Place>> search(String query, {GeoPoint? near}) => _store.behavior.query(() {
        final text = query.trim().toLowerCase();
        final found = [
          for (final p in MockFixtures.places)
            if ([p.name, p.categoryLabel, p.address].any((field) => field.toLowerCase().contains(text)))
              _store.placeWithSaved(p.id),
        ];
        if (near != null) {
          double distanceOf(Place p) => p.location == null ? double.infinity : near.distanceTo(p.location!);
          found.sort((a, b) => distanceOf(a).compareTo(distanceOf(b)));
        }
        return found;
      });
}

// NEEDS BACKEND: API 명세의 장소 검색 (팀 서버는 GET /places/search, 06 §0)
class ApiPlaceSearchRepository implements PlaceSearchRepository {
  ApiPlaceSearchRepository(this._client);
  // ignore: unused_field
  final ApiClient _client;

  @override
  Future<List<Place>> search(String query, {GeoPoint? near}) async =>
      throw const NotImplementedFailure('지도에서 검색하기');
}
