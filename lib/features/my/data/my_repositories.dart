import '../../../core/error/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../../../dev/mock/mock_fixtures.dart';
import '../../../dev/mock/mock_store.dart';
import '../domain/my_models.dart';

class MockMyRepository implements MyRepository {
  MockMyRepository(this._store);
  final MockStore _store;

  @override
  Future<MyProfile> fetchProfile() => _store.behavior.query(() {
        final labels = [
          for (final g in MockFixtures.preferenceGroups)
            for (final i in g.items)
              if (_store.preferenceKeys.contains(i.key)) i.label,
        ];
        return MyProfile(
          nickname: '김서연',
          handle: '@jin',
          savedPlaceCount: _store.savedIds.length,
          createdCourseCount: _store.courses.values.where((c) => !c.isParty).length,
          joinedCourseCount: _store.courses.values.where((c) => c.isParty).length,
          preferenceLabels: labels.take(5).toList(),
        );
      });
}

// NEEDS BACKEND: 내 프로필 + 통계 aggregate(저장한 장소·만든 코스·참여한 코스)
class ApiMyRepository implements MyRepository {
  ApiMyRepository(this._client);
  // ignore: unused_field
  final ApiClient _client;

  @override
  Future<MyProfile> fetchProfile() async => throw const NotImplementedFailure('마이');
}
