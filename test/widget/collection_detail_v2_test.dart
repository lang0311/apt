import 'package:apt/app/theme/app_theme.dart';
import 'package:apt/features/saved/presentation/pages/collection_detail_page.dart';
import 'package:apt/features/saved/presentation/widgets/place_list_tile.dart';
import 'package:apt/features/saved/presentation/widgets/saved_rows.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// 시안 v2 "16 · 17 보관함 상세": 칩 두 개(지도로 보기 · 장소 담기) 아래 화면 끝까지 가는 선 없는 행
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('장소는 테두리 카드가 아니라 저장됨과 같은 행, 머리 대신 장소 담기 칩', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CollectionDetailPage(collectionId: 'c1'),
        ),
      ),
    );
    // 보관함 → 장소 목록 순서로 불러온다 (Mock 지연 두 번)
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text('지도로 보기'), findsOneWidget);
    expect(find.text('장소 담기'), findsOneWidget);
    expect(find.text('저장된 장소'), findsNothing);
    expect(find.byType(SavedPlaceRow), findsWidgets);
    expect(find.byType(PlaceListTile), findsNothing);
    await tester.pump(const Duration(seconds: 2));
  });
}
