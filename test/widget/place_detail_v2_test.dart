import 'package:apt/app/theme/app_theme.dart';
import 'package:apt/features/place/presentation/widgets/place_action_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// 시안 v2 "20 장소 상세": 저장 · 카카오맵 · 전화를 칸 버튼으로, 서버가 주지 않은 값의 칸은 없다
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pump(WidgetTester tester, PlaceActionTiles tiles) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(20), child: tiles),
      ),
    ),
  );

  testWidgets('지도 · 전화가 다 있으면 저장됨 · 카카오맵 · 전화', (tester) async {
    await pump(tester, PlaceActionTiles(saved: true, onSave: () {}, onMap: () {}, onCall: () {}));
    expect(find.text('저장됨'), findsOneWidget);
    expect(find.text('카카오맵'), findsOneWidget);
    expect(find.text('전화'), findsOneWidget);
  });

  testWidgets('전화번호가 없으면 전화 칸 없음', (tester) async {
    await pump(tester, PlaceActionTiles(saved: false, onSave: () {}, onMap: () {}));
    expect(find.text('저장하기'), findsOneWidget);
    expect(find.text('카카오맵'), findsOneWidget);
    expect(find.text('전화'), findsNothing);
  });
}
