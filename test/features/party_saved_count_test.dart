import 'package:apt/core/network/api_client.dart';
import 'package:apt/features/platform/data/platform_client.dart';
import 'package:apt/features/platform/data/platform_repositories.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// 16번: 서버 `GET /parties/{id}`의 파티원별 `saved_place_count`
void main() {
  test('파티원 저장 수를 읽고, /me의 파티 목록처럼 값이 없으면 null', () async {
    final platform = _Fake({
      '/me': {
        'user': {'id': 'u0', 'name': '랑'},
        'parties': [
          {'id': 'p', 'owner': 'u0', 'members': [{'id': 'u0', 'name': '랑'}, {'id': 'u1', 'name': '지민'}, {'id': 'u2', 'name': '영서'}]},
        ],
        'places': [],
      },
      '/parties/p': {
        'members': [
          {'id': 'u0', 'name': '랑', 'login': 'test', 'saved_place_count': 24},
          {'id': 'u1', 'name': '지민', 'login': 'jimin', 'saved_place_count': 11},
          {'id': 'u2', 'name': '영서', 'login': 'youngseo', 'saved_place_count': 0},
        ],
      },
    });
    final repo = PlatformPartyRepository(platform);

    final party = await repo.fetchParty('p');
    expect(party.members.map((m) => m.savedPlaceCount), [24, 11, 0]);

    final mine = await repo.fetchMyParties();
    expect(mine.single.members.map((m) => m.savedPlaceCount), [null, null, null]);
  });
}

class _Fake extends PlatformClient {
  _Fake(this.responses) : super(ApiClient(Dio()));
  final Map<String, dynamic> responses;

  @override
  Future<dynamic> get(String path, [Map<String, dynamic>? query]) async => responses[path];
}
