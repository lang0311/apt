import 'party_models.dart';

abstract interface class PartyRepository {
  /// 코스 만들기 2/4에서 새 파티로 '다음'(또는 초대하기)을 누를 때 파티 생성 (나 포함)
  Future<Party> createParty();

  /// 내가 속한 파티 목록 (2/4 "어느 파티와 갈까요?")
  Future<List<Party>> fetchMyParties();

  Future<Party> fetchParty(String partyId);

  Future<InviteLink> createInviteLink(String partyId);

  /// 실패 시 [InviteFailure]
  Future<Invitation> fetchInvitation(String token);

  /// [shareMyPreferences]: "내 저장 장소와 취향을 추천에 반영" 체크 값
  Future<void> acceptInvitation(String token, {required bool shareMyPreferences});

  Future<void> declineInvitation(String token);
}
