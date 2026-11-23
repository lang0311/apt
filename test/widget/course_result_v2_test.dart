import 'package:apt/app/theme/app_colors.dart';
import 'package:apt/app/theme/app_theme.dart';
import 'package:apt/core/widgets/surfaces.dart';
import 'package:apt/features/course/presentation/widgets/course_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// 시안 v2 "30 추천 결과 (4/4)" · "32 코스 상세": 지금 배치 그대로(요약 세 칸 · 지도 · 일정 카드), v2 디자인
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pump(WidgetTester tester, Widget child, {double scale = 1}) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(size: const Size(360, 640), textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: Padding(padding: const EdgeInsets.all(20), child: child),
        ),
      ),
    ),
  );

  testWidgets('일정 카드(boxed)는 흰 바탕 + 1px 선, 모서리 20', (tester) async {
    await pump(tester, const SectionCard(title: '일정 5곳', boxed: true, child: Text('일정')));
    final c = tester.widget<Container>(find.descendant(of: find.byType(SectionCard), matching: find.byType(Container)).first);
    final d = c.decoration! as BoxDecoration;
    expect(d.color, AppColors.surface);
    expect((d.border! as Border).top.color, AppColors.divider);
    expect(d.borderRadius, BorderRadius.circular(20));
  });

  testWidgets('요약 세 칸은 따로 떨어진 채움 칸 (날짜 · 출발 · 거리), 360 · 1.3배에서 넘치지 않음', (tester) async {
    await pump(tester, CourseStats(date: DateTime(2026, 11, 24), start: const TimeOfDay(hour: 12, minute: 0)), scale: 1.3);
    final cells = tester
        .widgetList<Container>(find.descendant(of: find.byType(CourseStats), matching: find.byType(Container)))
        .where((c) => (c.decoration as BoxDecoration?)?.color == AppColors.fill)
        .toList();
    expect(cells.length, 2, reason: '좌표가 없어 거리 칸은 빠지고 날짜 · 출발 두 칸');
    expect(tester.takeException(), isNull);
  });
}
