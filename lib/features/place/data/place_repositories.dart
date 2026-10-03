import '../../../core/error/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../../../dev/mock/mock_store.dart';
import '../domain/place.dart';
import '../domain/place_repository.dart';

class MockPlaceRepository implements PlaceRepository {
  MockPlaceRepository(this._store);
  final MockStore _store;

  @override
  Future<PlaceDetail> fetchPlace(String placeId) => _store.behavior.query(() {
        final place = _store.placeWithSaved(placeId);
        return PlaceDetail(
          place: place,
          openStatusLabel: '영업 중',
          isOpen: true,
          closingLabel: '21:00 마감',
          collectionIds: [for (final e in _store.members.entries) if (e.value.contains(placeId)) e.key],
        );
      });
}

// NEEDS BACKEND: 장소 상세 API (영업 상태, 평점 출처, 원본 SNS 링크, 내 저장 상태/소속 보관함)
class ApiPlaceRepository implements PlaceRepository {
  ApiPlaceRepository(this._client);
  // ignore: unused_field
  final ApiClient _client;

  @override
  Future<PlaceDetail> fetchPlace(String placeId) async => throw const NotImplementedFailure('장소 상세');
}
