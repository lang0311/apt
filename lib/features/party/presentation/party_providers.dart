import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/repositories.dart';
import '../domain/party_models.dart';

final partyProvider = FutureProvider.autoDispose.family<Party, String>(
  (ref, partyId) => ref.watch(partyRepositoryProvider).fetchParty(partyId),
);

/// 초대 링크 (서버 생성)
final inviteLinkProvider = FutureProvider.autoDispose.family<InviteLink, String>(
  (ref, partyId) => ref.watch(partyRepositoryProvider).createInviteLink(partyId),
);

final invitationProvider = FutureProvider.autoDispose.family<Invitation, String>(
  (ref, token) => ref.watch(partyRepositoryProvider).fetchInvitation(token),
);
