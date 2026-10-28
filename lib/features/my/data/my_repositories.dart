import '../../../core/error/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../../../dev/mock/mock_store.dart';
import '../domain/my_models.dart';

class MockMyRepository implements MyRepository {
  MockMyRepository(this._store);
  final MockStore _store;

  @override
  Future<MyProfile> fetchProfile() => _store.behavior.query(() => MyProfile(
        nickname: '김서연',
        handle: '@jin',
        savedPlaceCount: _store.savedIds.length,
        createdCourseCount: _store.courses.values.where((c) => !c.isParty).length,
        joinedCourseCount: _store.courses.values.where((c) => c.isParty).length,
      ));
}

// NEEDS BACKEND: 내 프로필 + 통계 aggregate(저장한 장소·만든 코스·참여한 코스)
class ApiMyRepository implements MyRepository {
  ApiMyRepository(this._client);
  // ignore: unused_field
  final ApiClient _client;

  @override
  Future<MyProfile> fetchProfile() async => throw const NotImplementedFailure('마이');
}
