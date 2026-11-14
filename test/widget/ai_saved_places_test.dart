import 'package:apt/app/di/repositories.dart';
import 'package:apt/app/theme/app_theme.dart';
import 'package:apt/features/course/presentation/widgets/map_place_picker.dart';
import 'package:apt/features/place/domain/place.dart';
import 'package:apt/features/saved/domain/saved_models.dart';
import 'package:apt/features/saved/domain/saved_repository.dart';
import 'package:apt/features/saved/presentation/pages/saved_map_page.dart';
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
    await tester.tap(find.text('1곳 보기'));
    await tester.pumpAndSettle();
    expect(find.text('도시근린공원 1곳'), findsOneWidget);
    expect(find.text('우장근린공원'), findsOneWidget);
    expect(find.text('고드니 마곡본점'), findsNothing);
  });

  testWidgets('업종별로 보면 필터에서 업종을 여러 개 고르고, 고른 값만 칩으로 · 하나씩 푼다 (07 D48)', (tester) async {
    await pump(tester, const SavedPage());
    // 기본은 지역별 → 업종별로 바꾼다
    await tester.tap(find.text('지역별'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('업종별'));
    await tester.pumpAndSettle();

    // 업종: 한식 2 · 고궁,궁 1
    await tester.tap(find.text('필터'));
    await tester.pumpAndSettle();
    expect(find.text('3곳 보기'), findsOneWidget); // 아무것도 안 고르면 전체
    await tester.tap(find.text('한식').last); // 뒤 목록의 묶음 제목이 아니라 시트의 항목
    await tester.tap(find.text('고궁,궁').last);
    await tester.pumpAndSettle();
    expect(find.text('3곳 보기'), findsOneWidget);
    await tester.tap(find.text('초기화'));
    await tester.pump();
    await tester.tap(find.text('한식').last); // 뒤 목록의 묶음 제목이 아니라 시트의 항목
    await tester.pumpAndSettle();
    await tester.tap(find.text('2곳 보기'));
    await tester.pumpAndSettle();
    expect(find.text('2곳'), findsOneWidget);
    expect(find.text('경복궁'), findsNothing);

    // 다시 열어 하나 더 고르면 칩이 두 개
    await tester.tap(find.text('필터'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('고궁,궁').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('3곳 보기'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('한식 필터 해제'), findsOneWidget);
    expect(find.bySemanticsLabel('고궁,궁 필터 해제'), findsOneWidget);

    // 칩의 ×로 하나씩 풀기
    await tester.tap(find.bySemanticsLabel('한식 필터 해제'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('고궁,궁 필터 해제'));
    await tester.pumpAndSettle();
    expect(find.text('전체 3곳'), findsOneWidget);
  });

  group('저장 지도 (07 D48)', () {
    Widget map({bool aiOnly = false}) => SavedMapPage(mode: SavedMapMode.category, aiOnly: aiOnly);

    Finder inSheet(String text) => find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

    Future<void> filter(WidgetTester tester, List<String> taps) async {
      await tester.tap(find.bySemanticsLabel(RegExp(r'^카테고리 필터(,|$)')));
      await tester.pumpAndSettle();
      for (final t in taps) {
        await tester.tap(inSheet(t));
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('적용'));
      await tester.pumpAndSettle();
    }

    testWidgets('직접 저장 + 추천받은 곳이 함께, 필터 시트에서 켜고 끈다', (tester) async {
      await pump(tester, map());
      expect(find.text('5곳'), findsOneWidget); // 이 지역 5곳
      await filter(tester, ['직접 저장']);
      expect(find.text('2곳'), findsOneWidget);
      expect(find.text('추천받은 곳만'), findsWidgets);
      expect(find.text('test3 코스에서 추천'), findsWidgets); // 추천받은 곳 카드
      await filter(tester, ['직접 저장', '추천받은 곳']);
      expect(find.text('3곳'), findsOneWidget);
      await filter(tester, ['직접 저장']);
      expect(find.text('보여 줄 장소가 없어요'), findsOneWidget);
    });

    testWidgets('AI 추천 탭에서 들어오면 추천받은 곳만', (tester) async {
      await pump(tester, map(aiOnly: true));
      expect(find.text('2곳'), findsOneWidget);
      expect(find.text('추천받은 곳만'), findsWidgets);
    });

    testWidgets('필터: 카테고리를 여러 개 고르면 "첫째 외 n", ×로 풀기', (tester) async {
      await pump(tester, map());
      await filter(tester, ['한식', '디저트카페']);
      expect(find.text('3곳'), findsOneWidget);
      expect(find.bySemanticsLabel('카테고리 필터, 한식 외 1 적용됨'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('카테고리 필터 해제'));
      await tester.pumpAndSettle();
      expect(find.text('5곳'), findsOneWidget);
    });

    testWidgets('지도 위 목록 버튼: 가로 카드 대신 묶음 목록, 지도로 돌아가기', (tester) async {
      await pump(tester, map());
      await tester.tap(find.text('목록 5'));
      await tester.pumpAndSettle();
      expect(find.text('지도'), findsOneWidget);
      expect(find.textContaining('직접 저장 ', findRichText: true), findsOneWidget); // 묶음 제목 '직접 저장 3'
      await tester.tap(find.text('지도'));
      await tester.pumpAndSettle();
      expect(find.text('목록 5'), findsOneWidget);
    });

    testWidgets('360 폭에서 넘치지 않는다', (tester) async {
      await pump(tester, map(), width: 360);
      expect(tester.takeException(), isNull);
    });
  });

  group('코스 장소 고르기', () {
    Widget picker() => Scaffold(body: MapPlacePicker(selectedIds: const [], onToggle: (_) {}));

    Future<void> toggleSource(WidgetTester tester, String label) async {
      await tester.tap(find.byTooltip(RegExp('^필터')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text('적용'));
      await tester.pumpAndSettle();
    }

    testWidgets('기본은 둘 다 보이고, 필터 시트에서 한쪽씩 · 둘 다 끌 수 있다', (tester) async {
      await pump(tester, picker());
      expect(find.text('목록 5'), findsOneWidget);

      await toggleSource(tester, '직접 저장');
      expect(find.text('목록 2'), findsOneWidget);
      expect(find.text('추천받은 곳만'), findsOneWidget);

      await toggleSource(tester, '추천받은 곳');
      expect(find.text('목록 0'), findsOneWidget);
      expect(find.text('필터에서 직접 저장이나 추천받은 곳을 켜 보세요'), findsOneWidget);

      // 걸린 칩을 누르면 둘 다 다시 켠다
      await tester.tap(find.text('보여 줄 장소 없음'));
      await tester.pumpAndSettle();
      expect(find.text('목록 5'), findsOneWidget);
    });

    testWidgets('목록: 아래에서 올라오는 시트, 지역 묶음, 추천받은 곳에는 "○○ 코스에서 추천"', (tester) async {
      await pump(tester, picker());
      await tester.tap(find.text('목록 5'));
      await tester.pumpAndSettle();
      expect(find.text('저장한 장소  5', findRichText: true), findsOneWidget);
      expect(find.text('test3 코스에서 추천'), findsNWidgets(2));
      expect(find.text('지도로 보기'), findsOneWidget);

      await tester.tap(find.text('지도로 보기'));
      await tester.pumpAndSettle();
      expect(find.text('목록 5'), findsOneWidget);
    });

    testWidgets('카테고리를 여러 개 고르면 두 쪽 모두에서 거른다', (tester) async {
      await pump(tester, picker());
      await tester.tap(find.byTooltip('필터'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('한식'));
      await tester.tap(find.text('도시근린공원'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('적용'));
      await tester.pumpAndSettle();
      expect(find.text('목록 3'), findsOneWidget);
      expect(find.text('한식 외 1'), findsOneWidget);
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
