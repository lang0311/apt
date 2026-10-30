import 'package:apt/app/di/repositories.dart';
import 'package:apt/app/theme/app_theme.dart';
import 'package:apt/features/course/domain/course_models.dart';
import 'package:apt/features/course/presentation/course_draft_controller.dart';
import 'package:apt/features/course/presentation/pages/companion_page.dart';
import 'package:apt/features/party/domain/party_models.dart';
import 'package:apt/features/party/domain/party_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _CountingPartyRepository implements PartyRepository {
  int created = 0;
  static const _me = PartyMember(id: 'me', nickname: '나', isMe: true);

  @override
  Future<Party> createParty() async => Party(id: 'new${++created}', members: const [_me]);
  @override
  Future<List<Party>> fetchMyParties() async => const [
        Party(id: 'old', members: [_me, PartyMember(id: 'u2', nickname: '민지')]),
      ];
  @override
  Future<Party> fetchParty(String partyId) async => Party(id: partyId, members: const [_me]);
  @override
  Future<InviteLink> createInviteLink(String partyId) async => InviteLink(url: 'https://example.com/$partyId');
  @override
  Future<Invitation> fetchInvitation(String token) => throw UnimplementedError();
  @override
  Future<void> acceptInvitation(String token, {required bool shareMyPreferences}) async {}
  @override
  Future<void> declineInvitation(String token) async {}
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('새 파티를 만든 뒤 다른 파티를 골랐다가 돌아와도 파티를 또 만들지 않는다', (tester) async {
    tester.view.physicalSize = const Size(412, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _CountingPartyRepository();
    final container = ProviderContainer(overrides: [partyRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(container.dispose);
    container.read(courseDraftProvider.notifier).update((d) => d.copyWith(companion: Companion.party));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.light(), home: const CompanionPage()),
    ));
    await tester.pumpAndSettle();

    Future<void> inviteFromNewParty() async {
      await tester.tap(find.text('새 파티 만들기'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('초대하기'));
      await tester.tap(find.text('초대하기'));
      await tester.pumpAndSettle();
      // 초대 시트 닫기
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      expect(nav.canPop(), isTrue);
      nav.pop();
      await tester.pumpAndSettle();
    }

    await inviteFromNewParty();
    expect(repo.created, 1);
    expect(container.read(courseDraftProvider).partyId, 'new1');

    await tester.tap(find.text('나, 민지'));
    await tester.pumpAndSettle();
    expect(container.read(courseDraftProvider).partyId, 'old');

    await inviteFromNewParty();
    expect(repo.created, 1);
    expect(container.read(courseDraftProvider).partyId, 'new1');
  });
}
