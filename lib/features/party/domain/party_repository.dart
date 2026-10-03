import 'party_models.dart';

abstract interface class PartyRepository {
  /// 코스 만들기 3/4에서 "함께 갈게요" 선택 시 파티 생성 (나 포함)
  Future<Party> createParty();

  Future<Party> fetchParty(String partyId);

  Future<InviteLink> createInviteLink(String partyId);

  /// 실패 시 [InviteFailure]
  Future<Invitation> fetchInvitation(String token);

  /// [shareMyPreferences]: "내 저장 장소와 취향을 추천에 반영" 체크 값
  Future<void> acceptInvitation(String token, {required bool shareMyPreferences});

  Future<void> declineInvitation(String token);
}
