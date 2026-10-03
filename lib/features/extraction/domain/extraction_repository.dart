import 'extraction_models.dart';

abstract interface class ExtractionRepository {
  /// URL 제출 → 분석 → 결과.
  /// NEEDS BACKEND: 동기 응답인지 비동기(작업 ID + 폴링)인지. 비동기라면 이 메서드 내부에서
  /// 폴링하고 결과만 돌려주도록 구현해 화면 코드는 바꾸지 않는다.
  /// 실패 시 [ExtractionFailure].
  Future<ExtractionResult> extract(String url);

  Future<List<RecentExtraction>> fetchRecent({int limit = 2});
}
