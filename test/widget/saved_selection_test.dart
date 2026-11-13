import 'package:apt/app/di/repositories.dart';
import 'package:apt/app/theme/app_theme.dart';
import 'package:apt/core/error/app_failure.dart';
import 'package:apt/features/place/domain/place.dart';
import 'package:apt/features/saved/domain/saved_models.dart';
import 'package:apt/features/saved/domain/saved_repository.dart';
import 'package:apt/features/saved/presentation/pages/saved_page.dart';
import 'package:apt/features/saved/presentation/saved_providers.dart';
import 'package:apt/features/saved/presentation/saved_selection.dart';
import 'package:apt/features/saved/presentation/widgets/saved_rows.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Place _place(String id, String name) =>
    Place(id: id, name: name, address: '서울 마포구 서교동', categoryKey: '음식점 > 한식', categoryLabel: '한식');

/// 서버 모드처럼 보관함 없이 한 곳씩 지운다. [failOn]에 든 장소는 지우기에 실패한다.
class _FakeSavedRepository implements SavedRepository {
  _FakeSavedRepository({this.failOn = const {}});
  final Set<String> failOn;
  final mine = {'a': _place('a', '탕반가'), 'b': _place('b', '성미옥'), 'c': _place('c', '하남정')};
  final ai = {'x': _place('x', '경의선숲길')};
  final deleted = <String>[];
  final restored = <String>[];

  @override
  Future<SavedSummary> fetchSummary() async => SavedSummary(
        totalCount: mine.length,
        categories: [PlaceCategory(key: '음식점 > 한식', label: '한식', count: mine.length)],
      );

  @override
  Future<List<SavedPlaceItem>> fetchSavedPlaces(SavedPlaceQuery query) async => [for (final p in mine.values) SavedPlaceItem(place: p)];

  @override
  Future<List<SavedPlaceItem>> fetchAiSavedPlaces() async =>
      [for (final p in ai.values) SavedPlaceItem(place: p, recommendedIn: '연남 산책')];

  @override
  Future<void> unsavePlace(String placeId) async {
    if (failOn.contains(placeId)) throw const ServerFailure();
    deleted.add(placeId);
    mine.remove(placeId);
    ai.remove(placeId);
  }

  @override
  Future<void> savePlaces({required List<String> placeIds, required List<String> collectionIds}) async => restored.addAll(placeIds);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<ProviderContainer> pumpSaved(WidgetTester tester, _FakeSavedRepository repo) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        savedRepositoryProvider.overrideWithValue(repo),
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
    return container;
  }

  testWidgets('카테고리: 선택 → 2곳 고르기 → 삭제 → 되돌리기 (07 D45)', (tester) async {
    final repo = _FakeSavedRepository();
    final container = await pumpSaved(tester, repo);

    await tester.tap(find.text('선택'));
    await tester.pump();
    expect(container.read(savedSelectionProvider).active, isTrue);
    expect(find.text('0/3'), findsOneWidget);

    await tester.tap(find.text('성미옥'));
    await tester.tap(find.text('하남정'));
    await tester.pump();
    expect(find.text('2/3'), findsOneWidget);

    await tester.tap(find.text('2곳 삭제'));
    await tester.pumpAndSettle();
    expect(repo.deleted, ['b', 'c']);
    expect(container.read(savedSelectionProvider).active, isFalse);
    expect(find.text('2곳을 삭제했어요.'), findsOneWidget);

    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    expect(repo.restored, ['b', 'c']);
  });

  testWidgets('행을 길게 누르면 그 행을 고른 채로 선택이 시작되고, 전체 선택 · 완료로 푼다', (tester) async {
    final container = await pumpSaved(tester, _FakeSavedRepository());

    await tester.longPress(find.text('탕반가'));
    await tester.pump();
    expect(container.read(savedSelectionProvider).ids, {'a'});

    await tester.tap(find.text('전체 선택'));
    await tester.pump();
    expect(container.read(savedSelectionProvider).ids, {'a', 'b', 'c'});
    expect(find.text('3곳 삭제'), findsOneWidget);

    await tester.tap(find.text('완료'));
    await tester.pump();
    expect(container.read(savedSelectionProvider).active, isFalse);
  });

  testWidgets('일부만 지워지면 실패한 곳만 고른 채로 남고 다시 시도할 수 있다', (tester) async {
    final repo = _FakeSavedRepository(failOn: {'c'});
    final container = await pumpSaved(tester, repo);

    await tester.tap(find.text('선택'));
    await tester.pump();
    await tester.tap(find.text('전체 선택'));
    await tester.pump();
    await tester.tap(find.text('3곳 삭제'));
    await tester.pumpAndSettle();

    expect(repo.deleted, ['a', 'b']);
    expect(container.read(savedSelectionProvider).ids, {'c'});
    expect(find.text('2곳을 삭제했어요. 1곳은 삭제하지 못했어요.'), findsOneWidget);
    expect(find.text('삭제하지 못했어요'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
  });

  testWidgets('AI 추천 탭: 코스 이름을 보여 주고, 삭제 전에 한 번 묻고 되돌리기는 없다 (07 D44 · D45)', (tester) async {
    final repo = _FakeSavedRepository();
    await pumpSaved(tester, repo);

    await tester.tap(find.text('AI 추천'));
    await tester.pumpAndSettle();
    expect(find.text('AI 추천 1곳'), findsOneWidget);
    expect(find.text('연남 산책 코스에서 추천'), findsOneWidget);

    await tester.tap(find.text('선택'));
    await tester.pump();
    await tester.tap(find.text('경의선숲길'));
    await tester.pump();
    await tester.tap(find.text('1곳 삭제'));
    await tester.pumpAndSettle();
    expect(find.text('1곳을 삭제할까요?'), findsOneWidget);
    expect(repo.deleted, isEmpty);

    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(repo.deleted, ['x']);
    expect(find.text('1곳을 삭제했어요.'), findsOneWidget);
    expect(find.text('되돌리기'), findsNothing);
  });

  test('코스 이름 문구: 이름이 이미 "코스"로 끝나면 덧붙이지 않고, 모르면 "코스에서 추천"', () {
    expect(SavedPlaceRow.recommendedLabel('연남 산책'), '연남 산책 코스에서 추천');
    expect(SavedPlaceRow.recommendedLabel('추천 코스'), '추천 코스에서 추천');
    expect(SavedPlaceRow.recommendedLabel(null), '코스에서 추천');
  });
}
