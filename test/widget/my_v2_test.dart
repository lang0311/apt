import 'package:apt/app/theme/app_theme.dart';
import 'package:apt/features/course/domain/course_models.dart';
import 'package:apt/features/course/presentation/widgets/course_summary_card.dart';
import 'package:apt/features/my/presentation/my_page.dart';
import 'package:apt/features/preference/presentation/preference_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// 시안 v2 "22 코스 목록 · 33 마이 · 34 내 취향" (2026-11-21 사용자 결정)
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Widget app(Widget home, {double scale = 1}) => ProviderScope(
    child: MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: home,
    ),
  );

  testWidgets('취향: Mock이 취향 항목을 줘도 고르는 칩 대신 "저장한 장소로 취향을 읽어요"', (tester) async {
    await tester.pumpWidget(app(const PreferencePage()));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('내 취향'), findsOneWidget);
    expect(find.text('저장한 장소로 취향을 읽어요'), findsOneWidget);
    expect(find.text('취향 저장하기'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('마이: 내 취향은 "보기", 설정 제목 · 추천하지 않는 장소 개수 없음, 글자 1.3배에도 넘치지 않음', (tester) async {
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(const MyPage(), scale: 1.3));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('내 취향'), findsOneWidget);
    expect(find.text('보기'), findsOneWidget);
    expect(find.text('설정'), findsNothing);
    expect(find.text('추천하지 않는 장소'), findsOneWidget);
    expect(find.text('로그아웃'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 2));
  });

  group('코스 목록 행', () {
    Widget row(CourseSummary c) => app(
      Scaffold(
        body: CourseSummaryRow(course: c, onTap: () {}),
      ),
    );

    testWidgets('다가오는 코스는 오른쪽에 D-day만', (tester) async {
      final d = DateTime.now().add(const Duration(days: 9));
      await tester.pumpWidget(row(CourseSummary(id: '1', title: '망원 먹방', regionLabel: '마포구', placeCount: 4, date: d)));
      expect(find.text('D-9'), findsOneWidget);
      expect(find.text('마포구 · 4곳'), findsOneWidget);
    });

    testWidgets('날짜 없는 코스는 "날짜 미정"', (tester) async {
      await tester.pumpWidget(row(const CourseSummary(id: '1', title: '남산', placeCount: 3)));
      expect(find.text('날짜 미정'), findsOneWidget);
    });

    testWidgets('지난 코스는 날짜를 아래 줄에, 오른쪽은 비움', (tester) async {
      final d = DateTime.now().subtract(const Duration(days: 40));
      await tester.pumpWidget(row(CourseSummary(id: '1', title: '을지로', regionLabel: '중구', placeCount: 5, date: d)));
      expect(find.text('중구 · 5곳 · ${d.month}월 ${d.day}일'), findsOneWidget);
      expect(find.textContaining('D+'), findsNothing);
    });
  });
}
