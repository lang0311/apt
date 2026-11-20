import 'package:apt/app/theme/app_theme.dart';
import 'package:apt/features/saved/domain/saved_models.dart';
import 'package:apt/features/saved/presentation/widgets/saved_rows.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// 시안 v2 "14 저장됨 · 보관함": 2열 표지 그리드 (360 폭에서도 넘치지 않음)
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final list = [
    for (var i = 0; i < 4; i++) PlaceCollection(id: 'c$i', name: '아주 긴 보관함 이름 $i 주말 데이트 코스 모음', placeCount: i * 3),
  ];

  testWidgets('보관함 4개는 2열 두 줄, 표지는 정사각형', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: const MediaQueryData(size: Size(360, 640), textScaler: TextScaler.linear(1.3)),
        child: Scaffold(body: SingleChildScrollView(child: CollectionGrid(collections: list, onOpen: (_) {}))),
      ),
    ));
    final cards = find.byType(CollectionGridCard);
    expect(cards, findsNWidgets(4));
    final a = tester.getTopLeft(cards.at(0));
    final b = tester.getTopLeft(cards.at(1));
    final c = tester.getTopLeft(cards.at(2));
    expect(a.dy, b.dy, reason: '첫 줄에 두 개');
    expect(c.dy, greaterThan(a.dy), reason: '셋째는 다음 줄');
    final cover = tester.getSize(find.byType(MiniCollage).first);
    expect(cover.width, closeTo(cover.height, 0.5));
    expect(tester.takeException(), isNull);
  });
}
