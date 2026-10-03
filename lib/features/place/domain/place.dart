import '../../../core/models/geo_point.dart';

/// 장소 (서버의 장소 데이터). 저장 여부는 [isSaved]로만 표현하고,
/// 보관함 소속(SavedPlace ↔ Collection, 다대다)은 saved feature에서 다룬다.
///
/// 필드는 화면이 필요로 하는 정보 기준이다. 서버 필드명과의 매핑은 mapper에서 한다 (NEEDS BACKEND).
class Place {
  const Place({
    required this.id,
    required this.name,
    required this.address,
    this.areaLabel,
    required this.categoryKey,
    required this.categoryLabel,
    this.imageUrl,
    this.rating,
    this.keywords = const [],
    this.location,
    this.sourceUrl,
    this.sourceHandle,
    this.isSaved = false,
  });

  final String id;
  final String name;

  /// 전체 주소 (예: 서울 성동구 성수이로 18길 12)
  final String address;

  /// 짧은 지역 표기 (예: 서울 성동구 성수동)
  final String? areaLabel;

  /// 서버 카테고리 키. 아이콘/색 매핑에 사용하고, 모르는 키는 기본 아이콘.
  final String categoryKey;
  final String categoryLabel;
  final String? imageUrl;
  final double? rating;
  final List<String> keywords;
  final GeoPoint? location;

  /// 원본 SNS 게시물
  final String? sourceUrl;
  final String? sourceHandle;
  final bool isSaved;

  String get displayArea => areaLabel ?? address;

  Place copyWith({bool? isSaved}) => Place(
        id: id,
        name: name,
        address: address,
        areaLabel: areaLabel,
        categoryKey: categoryKey,
        categoryLabel: categoryLabel,
        imageUrl: imageUrl,
        rating: rating,
        keywords: keywords,
        location: location,
        sourceUrl: sourceUrl,
        sourceHandle: sourceHandle,
        isSaved: isSaved ?? this.isSaved,
      );
}

/// 장소 상세 (상세 화면 전용 추가 정보)
class PlaceDetail {
  const PlaceDetail({
    required this.place,
    this.openStatusLabel,
    this.isOpen,
    this.closingLabel,
    this.collectionIds = const [],
  });

  final Place place;

  /// 영업 상태 문구 (예: 영업 중). 서버 제공 값 그대로 표시.
  final String? openStatusLabel;
  final bool? isOpen;

  /// 마감 문구 (예: 21:00 마감)
  final String? closingLabel;

  /// 내가 이 장소를 넣어 둔 보관함
  final List<String> collectionIds;
}
