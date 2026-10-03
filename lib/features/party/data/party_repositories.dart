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

  static const _members = [
    PartyMember(id: 'u1', nickname: '나', isMe: true),
    PartyMember(id: 'u3', nickname: '민지'),
    PartyMember(id: 'u4', nickname: '랑이'),
  ];

  @override
  Future<Party> createParty() => _store.behavior.mutate(
        () => Party(id: _store.nextId('party'), members: _members, preferenceSummary: const ['카페', '맛집', '자연']),
      );

  @override
  Future<Party> fetchParty(String partyId) => _store.behavior.query(
        () => Party(id: partyId, members: _members, preferenceSummary: const ['카페', '맛집', '자연']),
      );

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
