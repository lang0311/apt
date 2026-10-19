import '../../../core/models/geo_point.dart';
import 'saved_models.dart';

abstract interface class SavedRepository {
  Future<SavedSummary> fetchSummary();

  Future<List<SavedPlaceItem>> fetchSavedPlaces(SavedPlaceQuery query);

  /// `GET /api/v1/places/nearby` (lat, lng, radius m) — 로그인 사용자의 저장 장소 중 [center]에서
  /// [radiusMeters] 안에 있는 것.
  /// 가정 (docs/API 초안 기준, 2026-10-19): 서버는 거리·카테고리/보관함 필터·페이징을 주지 않는다.
  /// 그래서 [query] 필터는 구현체가 응답에 적용하고, 내 위치 기준 거리는 화면 쪽에서 계산한다.
  /// NEEDS BACKEND: 응답 형식, 반경 최대값·결과 개수 제한.
  Future<List<SavedPlaceItem>> fetchSavedPlacesNearby(GeoPoint center, int radiusMeters, SavedPlaceQuery query);

  Future<List<PlaceCollection>> fetchCollections();

  Future<PlaceCollection> fetchCollection(String collectionId);

  /// 이름 검증(중복/길이) 실패 시 ValidationFailure
  Future<PlaceCollection> createCollection(String name);

  /// 장소들을 저장하고 지정한 보관함에 넣는다. [collectionIds]가 비어 있으면 "전체 저장 장소"에만 저장.
  Future<void> savePlaces({required List<String> placeIds, required List<String> collectionIds});

  /// 한 장소의 보관함 소속을 교체한다 (보관함 변경)
  Future<void> setPlaceCollections({required String placeId, required List<String> collectionIds});

  Future<List<String>> fetchPlaceCollectionIds(String placeId);

  Future<void> addPlacesToCollection({required String collectionId, required List<String> placeIds});
}
