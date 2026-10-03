import '../../../core/error/app_failure.dart';
import '../../../core/models/geo_point.dart';
import '../../../core/network/api_client.dart';
import '../domain/saved_models.dart';
import '../domain/saved_repository.dart';

/// 실서버 구현 자리. API 명세 수령 후 DTO + mapper를 `dto/`에 추가하고 여기서 호출한다.
// NEEDS BACKEND: 보관함·카테고리·저장 장소 API (다대다, 페이지네이션, bbox 조회)
class ApiSavedRepository implements SavedRepository {
  ApiSavedRepository(this._client);
  // ignore: unused_field
  final ApiClient _client;

  static const _f = NotImplementedFailure('저장');

  @override
  Future<SavedSummary> fetchSummary() async => throw _f;
  @override
  Future<List<SavedPlaceItem>> fetchSavedPlaces(SavedPlaceQuery query) async => throw _f;
  @override
  Future<List<SavedPlaceItem>> fetchSavedPlacesInBounds(GeoBounds bounds, SavedPlaceQuery query) async => throw _f;
  @override
  Future<List<PlaceCollection>> fetchCollections() async => throw _f;
  @override
  Future<PlaceCollection> fetchCollection(String collectionId) async => throw _f;
  @override
  Future<PlaceCollection> createCollection(String name) async => throw _f;
  @override
  Future<void> savePlaces({required List<String> placeIds, required List<String> collectionIds}) async => throw _f;
  @override
  Future<void> setPlaceCollections({required String placeId, required List<String> collectionIds}) async => throw _f;
  @override
  Future<List<String>> fetchPlaceCollectionIds(String placeId) async => throw _f;
  @override
  Future<void> addPlacesToCollection({required String collectionId, required List<String> placeIds}) async => throw _f;
}
