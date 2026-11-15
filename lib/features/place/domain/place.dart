import '../../../core/models/geo_point.dart';
import 'place_timing.dart';

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
    this.phone,
    this.mapUrl,
    this.timing,
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

  /// 전화번호 (팀 서버: 카카오 지도의 `phone`). 없으면 null
  final String? phone;

  /// 지도 서비스의 장소 페이지 주소 (팀 서버: 카카오맵 `place_url`). 없으면 null
  final String? mapUrl;

  /// 팝업 · 행사 · 신규 오픈 기간 (팀 서버 `temporal`). 일반 장소는 null
  final PlaceTiming? timing;
  final bool isSaved;

  String get displayArea => areaLabel ?? address;

  /// 목록 · 카드 · 시트에 쓰는 짧은 동네 이름 ('성수동', '마포구', '김포시'). 주소는 장소 상세의 `주소` 줄에서만 길게 보여 준다.
  String get shortArea => shortAreaOf(displayArea);

  /// 지역 묶음 이름: 구 · 군 · 시('강서구', '김포시'). 없으면 동네 이름, 그것도 없으면 빈 문자열
  String get district {
    final d = districtOf(displayArea);
    return d.isNotEmpty ? d : shortArea;
  }

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
        phone: phone,
        mapUrl: mapUrl,
        timing: timing,
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

/// 주소에서 동네 이름만 뽑는다. 마지막 낱말이 번지 · 건물 번호('416', '134-6')일 수 있어서 그대로 쓰지 않는다.
/// 동 · 읍 · 면 · 리 · 가('성수동', '을지로3가')가 있으면 그것, 없으면(도로명 주소) 구 · 군 · 시('마포구', '김포시'),
/// 그것도 없으면 빈 문자열.
/// '서울 마포구 서교동 367-5' → '서교동' · '서울 강서구 화곡로 416' → '강서구' · '경기 김포시 김포한강2로24번길 134-6' → '김포시'
String shortAreaOf(String address) {
  final parts = address.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  for (final pattern in [RegExp(r'^[가-힣]+\d*[동읍면리가]$'), RegExp(r'^[가-힣]+[구군시]$')]) {
    final found = parts.lastWhere(pattern.hasMatch, orElse: () => '');
    if (found.isNotEmpty) return found;
  }
  return '';
}

/// 주소에서 구 · 군 · 시만 뽑는다(지역 묶음용). 여럿이면 마지막('경기 성남시 분당구 …' → '분당구'). 없으면 빈 문자열
String districtOf(String address) {
  final pattern = RegExp(r'^[가-힣]+[구군시]$');
  return address.trim().split(RegExp(r'\s+')).lastWhere(pattern.hasMatch, orElse: () => '');
}
