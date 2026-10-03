import '../../../core/models/geo_point.dart';
import 'saved_models.dart';

abstract interface class SavedRepository {
  Future<SavedSummary> fetchSummary();

  Future<List<SavedPlaceItem>> fetchSavedPlaces(SavedPlaceQuery query);

  /// viewport(bbox) 기반 조회. 클러스터링 지원 여부는 서버 확인 필요 (NEEDS BACKEND).
  Future<List<SavedPlaceItem>> fetchSavedPlacesInBounds(GeoBounds bounds, SavedPlaceQuery query);

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
