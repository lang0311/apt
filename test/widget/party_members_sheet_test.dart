import 'package:apt/app/theme/app_theme.dart';
import 'package:apt/features/course/presentation/widgets/party_members_sheet.dart';
import 'package:apt/features/party/domain/party_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

List<PartyMember> _people(int n) => [for (var i = 0; i < n; i++) PartyMember(id: 'u$i', nickname: '사람$i', isMe: i == 0)];

Future<void> _pump(WidgetTester tester, Party party, {Size size = const Size(390, 844), double scale = 1}) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light(),
    home: MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
      child: Scaffold(body: SingleChildScrollView(child: PartyMembersSheet(party: party, onInvite: () {}, onShare: () {}))),
    ),
  ),
);

/// 시안 https://claude.ai/artifact/24Ro62D3yiXffdgMG1bnQE "18 · 8명이 다 모였을 때"
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('파티장 · 3명: 초대하기와 코스 알리기', (tester) async {
    await _pump(tester, Party(id: 'p', members: _people(3)));
    expect(find.text('함께하는 사람 3명'), findsOneWidget);
    expect(find.text('초대하기'), findsOneWidget);
    expect(find.text('코스 알리기'), findsOneWidget);
    expect(find.text('8명이 다 모여서 더 초대할 수 없어요.'), findsNothing);
  });

  testWidgets('파티장 · 8명: 초대하기 대신 안내 한 줄, 360 · 1.3배에서 넘치지 않음', (tester) async {
    await _pump(tester, Party(id: 'p', members: _people(8)), size: const Size(360, 1400), scale: 1.3);
    expect(find.text('초대하기'), findsNothing);
    expect(find.text('8명이 다 모여서 더 초대할 수 없어요.'), findsOneWidget);
    expect(find.text('코스 알리기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('파티원(파티장 아님) · 8명: 안내도 초대하기도 없다', (tester) async {
    await _pump(tester, Party(id: 'p', members: _people(8), isOwner: false));
    expect(find.text('초대하기'), findsNothing);
    expect(find.text('8명이 다 모여서 더 초대할 수 없어요.'), findsNothing);
  });
}
