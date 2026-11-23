import 'package:apt/app/theme/app_theme.dart';
import 'package:apt/features/course/presentation/widgets/course_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// 시안 v2 "30 추천 결과 (4/4)" · "32 코스 상세": 요약 칸 (날짜 · 출발 · 직선 거리)
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('좌표가 없으면 거리 칸은 빠지고 날짜 · 출발 두 칸, 360 · 1.3배에서 넘치지 않음', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(size: Size(360, 640), textScaler: TextScaler.linear(1.3)),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: CourseStats(date: DateTime(2026, 11, 24), start: const TimeOfDay(hour: 12, minute: 0)),
            ),
          ),
        ),
      ),
    );
    expect(find.text('날짜'), findsOneWidget);
    expect(find.text('출발'), findsOneWidget);
    expect(find.text('직선 거리'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
