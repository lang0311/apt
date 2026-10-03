import 'preference_models.dart';

abstract interface class PreferenceRepository {
  Future<List<PreferenceGroup>> fetchGroups();

  Future<MyPreferences> fetchMine();

  Future<void> save({required Set<String> selectedKeys, required bool autoAnalysisEnabled});
}
