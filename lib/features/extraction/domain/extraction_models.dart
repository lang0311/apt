import '../../place/domain/place.dart';

/// 추출 결과 후보 장소
class ExtractedPlace {
  const ExtractedPlace({required this.place, required this.alreadySaved});
  final Place place;
  final bool alreadySaved;
}

class ExtractionResult {
  const ExtractionResult({required this.sourceUrl, this.sourceHandle, required this.places});
  final String sourceUrl;
  final String? sourceHandle;
  final List<ExtractedPlace> places;
}

/// 홈의 "최근 추출한 장소"
class RecentExtraction {
  const RecentExtraction({required this.place, required this.sourceUrl, required this.extractedAt});
  final Place place;
  final String sourceUrl;
  final DateTime extractedAt;
}

/// 추출 실패 사유 (화면 분기용). 서버 실패 코드와의 매핑은 NEEDS BACKEND.
enum ExtractionFailureKind {
  invalidUrl('지원하지 않는 링크예요', '인스타그램 게시물 또는 릴스 링크인지 확인해주세요.'),
  privatePost('비공개 게시물이에요', '공개 게시물만 장소를 찾을 수 있어요.'),
  noPlaceFound('장소를 찾지 못했어요', '게시물에서 장소 정보를 발견하지 못했어요. 다른 게시물로 시도해보세요.'),
  failed('분석에 실패했어요', '일시적인 문제일 수 있어요. 잠시 후 다시 시도해주세요.');

  const ExtractionFailureKind(this.title, this.description);
  final String title;
  final String description;
}

class ExtractionFailure implements Exception {
  const ExtractionFailure(this.kind);
  final ExtractionFailureKind kind;

  @override
  String toString() => kind.title;
}
