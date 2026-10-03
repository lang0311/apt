import '../../../core/error/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/instagram_url.dart';
import '../../../dev/mock/mock_store.dart';
import '../domain/extraction_models.dart';
import '../domain/extraction_repository.dart';

/// Mock 추출. URL에 따라 실패 상태를 흉내낸다:
/// `private` → 비공개, `none` → 장소 없음, `fail` → 실패
class MockExtractionRepository implements ExtractionRepository {
  MockExtractionRepository(this._store);
  final MockStore _store;

  @override
  Future<ExtractionResult> extract(String url) async {
    if (!InstagramUrl.isValid(url)) throw const ExtractionFailure(ExtractionFailureKind.invalidUrl);
    return _store.behavior.mutate(
      () {
        if (url.contains('private')) throw const ExtractionFailure(ExtractionFailureKind.privatePost);
        if (url.contains('none')) throw const ExtractionFailure(ExtractionFailureKind.noPlaceFound);
        if (url.contains('fail')) throw const ExtractionFailure(ExtractionFailureKind.failed);
        final ids = url.contains('reel') ? ['p4', 'p6'] : ['p1', 'p2'];
        return ExtractionResult(
          sourceUrl: url,
          sourceHandle: '@seoul_daily',
          places: [
            for (final id in ids)
              ExtractedPlace(place: _store.placeWithSaved(id), alreadySaved: _store.savedIds.contains(id)),
          ],
        );
      },
      // LLM 분석은 느리다 → 단계형 로딩 확인용 지연
      latency: const Duration(milliseconds: 2600),
    );
  }

  @override
  Future<List<RecentExtraction>> fetchRecent({int limit = 2}) => _store.behavior.query(
        () => [
          RecentExtraction(
            place: _store.placeWithSaved('p1'),
            sourceUrl: 'https://www.instagram.com/p/C3k9xYzAbcD/',
            extractedAt: DateTime.now().subtract(const Duration(days: 2)),
          ),
          RecentExtraction(
            place: _store.placeWithSaved('p4'),
            sourceUrl: 'https://www.instagram.com/reel/DA7mNpQrStU/',
            extractedAt: DateTime.now().subtract(const Duration(days: 3)),
          ),
        ].take(limit).toList(),
        empty: () => const [],
      );
}

// NEEDS BACKEND: 추출 API (동기/비동기, 진행 상태 조회, 결과 후보, 이미 저장 여부, 실패 사유 코드)
class ApiExtractionRepository implements ExtractionRepository {
  ApiExtractionRepository(this._client);
  // ignore: unused_field
  final ApiClient _client;

  static const _f = NotImplementedFailure('장소 추출');

  @override
  Future<ExtractionResult> extract(String url) async => throw _f;
  @override
  Future<List<RecentExtraction>> fetchRecent({int limit = 2}) async => throw _f;
}
