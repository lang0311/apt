import 'package:apt/app/di/repositories.dart';
import 'package:apt/app/theme/app_theme.dart';
import 'package:apt/features/party/domain/party_models.dart';
import 'package:apt/features/party/domain/party_repository.dart';
import 'package:apt/features/party/presentation/widgets/invite_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// 시안 https://claude.ai/artifact/24Ro62D3yiXffdgMG1bnQE "17 · 초대 링크 안내"
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<_Repo> open(WidgetTester tester, {Duration? expiresIn = const Duration(hours: 24)}) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    final repo = _Repo(expiresIn);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [partyRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(onPressed: () => showInviteModal(context, partyId: 'p'), child: const Text('열기')),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('링크 하나에 한 명 · 서버 유효 시간 안내', (tester) async {
    await open(tester);
    expect(find.text('링크 하나에 한 명씩 들어올 수 있어요.\n24시간이 지나면 열리지 않아요.'), findsOneWidget);
    expect(find.text('새 링크'), findsNothing);
  });

  testWidgets('유효 시간을 모르면 시간 없이 안내', (tester) async {
    await open(tester, expiresIn: null);
    expect(find.text('링크 하나에 한 명씩 들어올 수 있어요.'), findsOneWidget);
  });

  testWidgets('복사하면 "복사했어요" + 새 링크, 새 링크를 누르면 링크를 다시 만든다', (tester) async {
    final repo = await open(tester);
    expect(repo.created, 1);

    await tester.tap(find.text('초대 링크 복사'));
    await tester.pumpAndSettle();
    expect(find.text('복사했어요'), findsOneWidget);
    expect(find.text('새 링크'), findsOneWidget);

    await tester.tap(find.text('새 링크'));
    await tester.pumpAndSettle();
    expect(repo.created, 2);
    expect(find.text('복사했어요'), findsNothing);
    expect(find.text('링크로 초대하기'), findsOneWidget);
  });
}

class _Repo implements PartyRepository {
  _Repo(this.expiresIn);
  final Duration? expiresIn;
  int created = 0;

  @override
  Future<InviteLink> createInviteLink(String partyId) async => InviteLink(url: 'https://x/invites/${++created}', expiresIn: expiresIn);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
