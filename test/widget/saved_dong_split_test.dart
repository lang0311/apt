import 'package:apt/app/di/repositories.dart';
import 'package:apt/app/theme/app_theme.dart';
import 'package:apt/features/place/domain/place.dart';
import 'package:apt/features/saved/domain/saved_models.dart';
import 'package:apt/features/saved/domain/saved_repository.dart';
import 'package:apt/features/saved/presentation/pages/saved_page.dart';
import 'package:apt/features/saved/presentation/saved_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Place _p(String id, String address) =>
    Place(id: id, name: '장소$id', address: address, categoryKey: '음식점 > 한식', categoryLabel: '한식');

/// 마포구 24곳(연남동 12 · 망원동 8 · 상암동 4) + 강서구 2곳
class _Repo implements SavedRepository {
  final places = [
    for (var i = 0; i < 12; i++) _p('y$i', '서울 마포구 연남동 $i'),
    for (var i = 0; i < 8; i++) _p('m$i', '서울 마포구 망원동 $i'),
    for (var i = 0; i < 4; i++) _p('s$i', '서울 마포구 상암동 $i'),
    _p('g1', '서울 강서구 화곡동 1'),
    _p('g2', '서울 강서구 화곡동 2'),
  ];

  @override
  Future<SavedSummary> fetchSummary() async => summarizeByCategory(places);

  @override
  Future<List<SavedPlaceItem>> fetchSavedPlaces(SavedPlaceQuery query) async => [for (final p in places) SavedPlaceItem(place: p)];

  @override
  Future<List<SavedPlaceItem>> fetchAiSavedPlaces() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

/// 지역별 보기에서 한 지역이 20곳을 넘으면 동네 줄로 나눈다 (07 D59)
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('20곳 넘는 지역은 동네 줄, 누르면 그 동네로 거른다', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        savedRepositoryProvider.overrideWithValue(_Repo()),
        collectionsSupportedProvider.overrideWithValue(false),
      ],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.light(), home: const SavedPage()),
    ));
    await tester.pumpAndSettle();

    // 마포구(24곳)는 동네 줄, 강서구(2곳)는 장소 줄
    expect(find.text('연남동 12곳'), findsOneWidget);
    expect(find.text('망원동 8곳'), findsOneWidget);
    expect(find.text('상암동 4곳'), findsOneWidget);
    expect(find.text('장소g1'), findsOneWidget);
    expect(find.textContaining('마포구 24곳 모두 보기'), findsNothing);
    // 많은 동네부터
    expect(tester.getTopLeft(find.text('연남동 12곳')).dy, lessThan(tester.getTopLeft(find.text('망원동 8곳')).dy));

    await tester.tap(find.text('망원동 8곳'));
    await tester.pumpAndSettle();
    // v2: 제목 줄 'n곳'은 없고, 고른 동네 칩만 남는다
    expect(find.text('장소m0'), findsOneWidget);
    expect(find.text('장소y0'), findsNothing);
    expect(find.bySemanticsLabel('마포구 망원동 필터 해제'), findsOneWidget);
  });
}
