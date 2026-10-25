import 'package:apt/app/theme/app_theme.dart';
import 'package:apt/core/models/geo_point.dart';
import 'package:apt/dev/mock/mock_store.dart';
import 'package:apt/features/place/data/place_search_repositories.dart';
import 'package:apt/features/place/presentation/place_search_page.dart';
import 'package:apt/features/saved/presentation/widgets/category_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('Mock 지도 검색', () {
    test('이름·업종·주소로 찾고 저장 상태를 같이 준다', () async {
      final repo = MockPlaceSearchRepository(MockStore());
      final byName = await repo.search('한강');
      expect(byName.map((p) => p.id), ['p6']);
      expect(byName.single.isSaved, isFalse);

      final byCategory = await repo.search('카페');
      expect(byCategory.map((p) => p.id), containsAll(['p1', 'p8']));
      expect(byCategory.every((p) => p.isSaved), isTrue);
    });

    test('위치를 주면 가까운 순', () async {
      final repo = MockPlaceSearchRepository(MockStore());
      // 가평 근처에서 '카페' → 산아래 커피(p8)가 먼저
      final near = await repo.search('카페', near: const GeoPoint(37.75, 127.35));
      expect(near.first.id, 'p8');
    });
  });

  test('카카오 업종 이름도 아이콘·색을 고른다', () {
    expect(CategoryStyle.of('음식점 > 카페 > 커피전문점'), same(CategoryStyle.of('cafe')));
    expect(CategoryStyle.of('음식점 > 한식'), same(CategoryStyle.of('restaurant')));
    expect(CategoryStyle.of('여행 > 관광,명소'), same(CategoryStyle.of('tour')));
    expect(CategoryStyle.of('기타'), same(CategoryStyle.fallback));
  });

  testWidgets('찾은 곳을 카드로 보여 주고 저장하면 저장됨으로 바뀐다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(retry: (_, _) => null);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.light(), home: const PlaceSearchPage()),
    ));

    expect(find.textContaining('가게 이름으로 찾아요'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '한강');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    // 한 번 그려서 검색을 시작한 뒤 Mock 지연(0.6초)을 지난다
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('한강 노을 포인트'), findsWidgets);
    expect(find.bySemanticsLabel('한강 노을 포인트 저장'), findsOneWidget);
    expect(find.bySemanticsLabel('한강 노을 포인트 보관함에 담기'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('한강 노을 포인트 저장'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.bySemanticsLabel('한강 노을 포인트 저장됨'), findsOneWidget);
    expect(find.text('저장됨에 추가했어요.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  });
}
