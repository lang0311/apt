import '../../../core/models/geo_point.dart';
import 'place.dart';

/// 지도에서 장소 찾기 (추출 탭 '지도에서 검색하기', 07 D32).
/// 찾은 장소의 저장은 [SavedRepository.savePlaces]에 찾은 id를 그대로 넘긴다.
abstract interface class PlaceSearchRepository {
  /// [near]가 있으면 그 주변에서 가까운 순으로 찾는다 ('현재 지도에서 검색하기').
  Future<List<Place>> search(String query, {GeoPoint? near});
}
