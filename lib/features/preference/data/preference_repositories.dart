import '../../../core/error/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../../../dev/mock/mock_fixtures.dart';
import '../../../dev/mock/mock_store.dart';
import '../domain/preference_models.dart';
import '../domain/preference_repository.dart';

class MockPreferenceRepository implements PreferenceRepository {
  MockPreferenceRepository(this._store);
  final MockStore _store;

  @override
  Future<List<PreferenceGroup>> fetchGroups() => _store.behavior.query(() => MockFixtures.preferenceGroups);

  @override
  Future<MyPreferences> fetchMine() => _store.behavior.query(
        () => MyPreferences(
          selectedKeys: {..._store.preferenceKeys},
          autoAnalysisSupported: true,
          autoAnalysisEnabled: _store.autoAnalysis,
          analyzedLabels: const ['카페', '오션뷰', '베이커리'],
          analysisBasisCount: _store.savedIds.length,
        ),
        empty: () => const MyPreferences(selectedKeys: {}),
      );

  @override
  Future<void> save({required Set<String> selectedKeys, required bool autoAnalysisEnabled}) =>
      _store.behavior.mutate(() {
        _store.preferenceKeys = {...selectedKeys};
        _store.autoAnalysis = autoAnalysisEnabled;
      });
}

// NEEDS BACKEND: 취향 키워드 체계(그룹/항목), 내 취향 조회/저장, 자동 분석 동의 플래그
class ApiPreferenceRepository implements PreferenceRepository {
  ApiPreferenceRepository(this._client);
  // ignore: unused_field
  final ApiClient _client;

  static const _f = NotImplementedFailure('취향 설정');

  @override
  Future<List<PreferenceGroup>> fetchGroups() async => throw _f;
  @override
  Future<MyPreferences> fetchMine() async => throw _f;
  @override
  Future<void> save({required Set<String> selectedKeys, required bool autoAnalysisEnabled}) async => throw _f;
}
