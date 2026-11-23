import 'package:apt/app/theme/app_theme.dart';
import 'package:apt/features/course/domain/course_models.dart';
import 'package:apt/features/course/presentation/widgets/course_summary_card.dart';
import 'package:apt/features/my/presentation/my_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// 시안 v2 "22 코스 목록 · 33 마이" (2026-11-21 사용자 결정)
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Widget app(Widget home) => ProviderScope(
    child: MaterialApp(theme: AppTheme.light(), home: home),
  );

  testWidgets('마이: 내 취향은 "보기", 추천하지 않는 장소 · 로그아웃', (tester) async {
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(const MyPage()));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('내 취향'), findsOneWidget);
    expect(find.text('보기'), findsOneWidget);
    expect(find.text('추천하지 않는 장소'), findsOneWidget);
    expect(find.text('로그아웃'), findsOneWidget);
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
