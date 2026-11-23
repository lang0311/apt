import '../../../core/models/geo_point.dart';
import 'place.dart';

/// 지도 가운데 주변을 업종으로 찾는 칩 (10번). 서버(카카오)가 지원하는 네 가지만.
/// [styleKey]는 앱 카테고리 아이콘 · 색 키 (CategoryStyle)
enum PlaceSearchCategory {
  cafe('카페', 'cafe'),
  restaurant('음식점', 'restaurant'),
  culture('문화시설', 'culture'),
  tour('관광명소', 'tour');

  const PlaceSearchCategory(this.label, this.styleKey);
  final String label;
  final String styleKey;
}

/// 지도에서 장소 찾기 (추출 탭 '지도에서 검색하기', 07 D32).
/// 찾은 장소의 저장은 [SavedRepository.savePlaces]에 찾은 id를 그대로 넘긴다.
abstract interface class PlaceSearchRepository {
  /// [near]가 있으면 그 주변에서 가까운 순으로 찾는다 ('현재 지도에서 검색하기').
  /// [query]가 비어 있으면 [category]로 [near] 주변을 찾는다 (둘 다 있어야 한다, 10번).
  Future<List<Place>> search(String query, {GeoPoint? near, PlaceSearchCategory? category});
}
