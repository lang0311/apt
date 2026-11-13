import 'package:apt/app/di/repositories.dart';
import 'package:apt/app/theme/app_theme.dart';
import 'package:apt/features/course/presentation/widgets/map_place_picker.dart';
import 'package:apt/features/place/domain/place.dart';
import 'package:apt/features/saved/domain/saved_models.dart';
import 'package:apt/features/saved/domain/saved_repository.dart';
import 'package:apt/features/saved/presentation/pages/saved_page.dart';
import 'package:apt/features/saved/presentation/saved_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Place _place(String id, String name, String category) =>
    Place(id: id, name: name, address: '서울 마포구 서교동', categoryKey: category, categoryLabel: category.split('>').last.trim());

/// 서버 모드처럼 직접 저장 3곳 + 코스를 저장할 때 추천받아 들어온 2곳
class _FakeSavedRepository implements SavedRepository {
  final mine = [
    _place('a', '탕반가', '음식점 > 한식'),
    _place('b', '성미옥', '음식점 > 한식'),
    _place('c', '경복궁', '여행 > 관광,명소 > 고궁,궁'),
  ];
  final ai = [
    _place('x', '고드니 마곡본점', '음식점 > 카페 > 디저트카페'),
    _place('y', '우장근린공원', '여행 > 공원 > 도시근린공원'),
  ];

  @override
  Future<SavedSummary> fetchSummary() async => summarizeByCategory(mine);

  @override
  Future<List<SavedPlaceItem>> fetchSavedPlaces(SavedPlaceQuery query) async => [
        for (final p in mine)
          if ((query.categoryKey == null || p.categoryKey == query.categoryKey) && (query.keyword == null || p.name.contains(query.keyword!)))
            SavedPlaceItem(place: p),
      ];

  @override
  Future<List<SavedPlaceItem>> fetchAiSavedPlaces() async => [for (final p in ai) SavedPlaceItem(place: p, recommendedIn: 'test3')];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

/// 추천받아 저장된 곳의 필터 · 코스 장소 고르기에 함께 보이기 (07 D47)
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pump(WidgetTester tester, Widget home, {double width = 390}) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        savedRepositoryProvider.overrideWithValue(_FakeSavedRepository()),
        collectionsSupportedProvider.overrideWithValue(false),
      ],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.light(), home: home),
    ));
    await tester.pumpAndSettle();
  }

  test('카테고리별로 세고, 두 요약은 같은 카테고리끼리 더한다', () {
    final a = summarizeByCategory([
      _place('1', 'A', '음식점 > 한식'),
      _place('2', 'B', '음식점 > 한식'),
      _place('3', 'C', ''),
    ]);
    expect(a.totalCount, 3);
    expect([for (final c in a.categories) (c.key, c.label, c.count)], [('음식점 > 한식', '한식', 2), ('기타', '기타', 1)]);
    final merged = mergeSummaries(a, summarizeByCategory([_place('4', 'D', '음식점 > 한식'), _place('5', 'E', '여행 > 공원')]));
    expect(merged.totalCount, 5);
    expect([for (final c in merged.categories) (c.label, c.count)], [('한식', 3), ('기타', 1), ('공원', 1)]);
  });

  testWidgets('저장됨 AI 추천 탭: 전체 n곳 · 필터, 고르면 그 카테고리만', (tester) async {
    await pump(tester, const SavedPage());
    await tester.tap(find.text('AI 추천'));
    await tester.pumpAndSettle();
    expect(find.text('전체 2곳'), findsOneWidget);

    await tester.tap(find.text('필터'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('도시근린공원'));
    await tester.pumpAndSettle();
    expect(find.text('도시근린공원 1곳'), findsOneWidget);
    expect(find.text('우장근린공원'), findsOneWidget);
    expect(find.text('고드니 마곡본점'), findsNothing);
  });

  group('코스 장소 고르기', () {
    Widget picker() => Scaffold(body: MapPlacePicker(selectedIds: const [], onToggle: (_) {}));

    testWidgets('기본은 둘 다 보이고, 칩으로 한쪽씩 · 둘 다 끌 수 있다', (tester) async {
      await pump(tester, picker());
      expect(find.text('목록 5'), findsOneWidget);

      await tester.tap(find.text('직접 저장'));
      await tester.pumpAndSettle();
      expect(find.text('목록 2'), findsOneWidget);
      expect(find.bySemanticsLabel('직접 저장 숨김'), findsOneWidget);

      await tester.tap(find.text('추천받은 곳'));
      await tester.pumpAndSettle();
      expect(find.text('목록 0'), findsOneWidget);
      expect(find.text('직접 저장이나 추천받은 곳을 켜 보세요'), findsOneWidget);

      await tester.tap(find.text('직접 저장'));
      await tester.pumpAndSettle();
      expect(find.text('목록 3'), findsOneWidget);
    });

    testWidgets('목록: 직접 저장 → 추천받은 곳 묶음, 추천받은 곳에는 "○○ 코스에서 추천"', (tester) async {
      await pump(tester, picker());
      await tester.tap(find.text('목록 5'));
      await tester.pumpAndSettle();
      expect(find.text('직접 저장 3'), findsOneWidget);
      expect(find.text('추천받은 곳 2'), findsOneWidget);
      expect(tester.getTopLeft(find.text('직접 저장 3')).dy, lessThan(tester.getTopLeft(find.text('추천받은 곳 2')).dy));
      expect(find.text('test3 코스에서 추천'), findsNWidgets(2));

      // 한쪽만 보이면 묶음 제목 없이
      await tester.tap(find.text('직접 저장'));
      await tester.pumpAndSettle();
      expect(find.text('추천받은 곳 2'), findsNothing);
      expect(find.text('고드니 마곡본점'), findsOneWidget);
    });

    testWidgets('360 폭에서 칩 막대가 넘치지 않는다', (tester) async {
      await pump(tester, picker(), width: 360);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('목록 5'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
