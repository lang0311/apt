import '../../place/domain/place.dart';

/// 카테고리 (유형별 축, 서버 데이터). 목록과 개수 모두 서버 값을 표시한다.
class PlaceCategory {
  const PlaceCategory({required this.key, required this.label, required this.count});
  final String key;
  final String label;
  final int count;
}

/// 저장됨 요약 (서버 aggregate). 앱에서 전체 목록을 받아 count하지 않는다.
class SavedSummary {
  const SavedSummary({required this.totalCount, required this.categories});
  final int totalCount;
  final List<PlaceCategory> categories;
}

/// 보관함 (목적별 축, 사용자 생성). 한 장소는 여러 보관함에 속할 수 있다.
class PlaceCollection {
  const PlaceCollection({
    required this.id,
    required this.name,
    required this.placeCount,
    this.thumbnailUrls = const [],
    this.updatedAt,
  });

  final String id;
  final String name;
  final int placeCount;

  /// 콜라주 썸네일 (최대 4장 사용)
  final List<String> thumbnailUrls;
  final DateTime? updatedAt;
}

enum SavedSort {
  recent('최근 저장'),
  nearest('가까운 순'),
  rating('평점 순');

  const SavedSort(this.label);
  final String label;
}

/// 저장 장소 조회 조건
class SavedPlaceQuery {
  const SavedPlaceQuery({this.collectionId, this.keyword, this.sort = SavedSort.recent});
  final String? collectionId;
  final String? keyword;
  final SavedSort sort;

  @override
  bool operator ==(Object other) =>
      other is SavedPlaceQuery &&
      other.collectionId == collectionId &&
      other.keyword == keyword &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(collectionId, keyword, sort);
}

/// 지도/목록에 쓰는 저장 장소 + 내 위치 기준 거리 정보 (서버 제공 시)
class SavedPlaceItem {
  const SavedPlaceItem({required this.place, this.distanceMeters, this.recommendedIn});
  final Place place;
  final int? distanceMeters;

  /// AI 추천 탭: 이 장소를 추천한 코스 이름. 어느 코스인지 모르면 null (07 D44)
  final String? recommendedIn;
}

/// 저장 지도 기준
enum SavedMapMode { category, collection }
