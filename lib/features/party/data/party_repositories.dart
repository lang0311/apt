import '../../../core/error/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../../../dev/mock/mock_fixtures.dart';
import '../../../dev/mock/mock_store.dart';
import '../domain/party_models.dart';
import '../domain/party_repository.dart';

/// Mock 파티. 초대 토큰 `expired` / `joined` / `full` 로 예외 상태를 확인할 수 있다.
class MockPartyRepository implements PartyRepository {
  MockPartyRepository(this._store);
  final MockStore _store;

  static const _me = PartyMember(id: 'u1', nickname: '나', isMe: true);
  static const _members = [_me, PartyMember(id: 'u3', nickname: '민지'), PartyMember(id: 'u4', nickname: '랑이')];

  /// 이미 있는 파티(party1은 Mock 파티 코스의 파티). 새로 만든 파티는 나 혼자로 시작한다.
  final Map<String, List<PartyMember>> _parties = {
    'party1': _members,
    'party2': const [_me, PartyMember(id: 'u5', nickname: '도윤')],
    'party3': const [
      _me,
      PartyMember(id: 'u6', nickname: '김하늘바다'),
      PartyMember(id: 'u7', nickname: '이서준'),
      PartyMember(id: 'u8', nickname: '박지우'),
      PartyMember(id: 'u9', nickname: '최유나'),
    ],
  };

  Party _party(String id) =>
      Party(id: id, members: _parties[id] ?? _members, preferenceSummary: const ['카페', '맛집', '자연']);

  @override
  Future<Party> createParty() => _store.behavior.mutate(() {
        final id = _store.nextId('party-new-'); // party1~3과 겹치지 않게
        _parties[id] = const [_me];
        return _party(id);
      });

  @override
  Future<List<Party>> fetchMyParties() => _store.behavior.query(() => [for (final id in _parties.keys) _party(id)]);

  @override
  Future<Party> fetchParty(String partyId) => _store.behavior.query(() => _party(partyId));

  @override
  Future<InviteLink> createInviteLink(String partyId) =>
      _store.behavior.mutate(() => InviteLink(url: 'https://apt.example.com/invites/demo-$partyId'));

  @override
  Future<Invitation> fetchInvitation(String token) => _store.behavior.query(() {
        final failure = switch (token) {
          'expired' => InviteFailureKind.expired,
          'joined' => InviteFailureKind.alreadyJoined,
          'full' => InviteFailureKind.full,
          _ => null,
        };
        if (failure != null) throw InviteFailure(failure);
        return Invitation(
          token: token,
          inviterName: '민지',
          courseTitle: '가을 서울 카페 산책',
          courseDate: DateTime(2026, 10, 12),
          memberCount: 3,
          selectedPlaceCount: 3,
          previewPlaceNames: const ['카페 온더뷰', '코지 베이커리', '성수 정원'],
          previewImageUrl: MockFixtures.place('p1').imageUrl,
        );
      });

  @override
  Future<void> acceptInvitation(String token, {required bool shareMyPreferences}) =>
      _store.behavior.mutate(() {});

  @override
  Future<void> declineInvitation(String token) => _store.behavior.mutate(() {});
}

// NEEDS BACKEND: 초대 링크 생성, 수락/거절, 만료·중복·인원 초과 에러, 멤버 목록, 파티원 취향 요약
class ApiPartyRepository implements PartyRepository {
  ApiPartyRepository(this._client);
  // ignore: unused_field
  final ApiClient _client;

  static const _f = NotImplementedFailure('파티');

  @override
  Future<Party> createParty() async => throw _f;
  @override
  Future<List<Party>> fetchMyParties() async => throw _f;
  @override
  Future<Party> fetchParty(String partyId) async => throw _f;
  @override
  Future<InviteLink> createInviteLink(String partyId) async => throw _f;
  @override
  Future<Invitation> fetchInvitation(String token) async => throw _f;
  @override
  Future<void> acceptInvitation(String token, {required bool shareMyPreferences}) async => throw _f;
  @override
  Future<void> declineInvitation(String token) async => throw _f;
}
