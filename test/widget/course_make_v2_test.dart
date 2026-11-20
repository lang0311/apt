import 'package:apt/app/theme/app_theme.dart';
import 'package:apt/features/course/presentation/pages/course_info_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// 시안 v2 "23 정보 (1/4)": 코스 이름 · 날짜 · 출발 시간만 (분위기 칩 없음, 2026-11-21 사용자 결정)
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('1/4에는 분위기 칩이 없다 (Mock이 분위기 목록을 줘도)', (tester) async {
    await tester.pumpWidget(ProviderScope(child: MaterialApp(theme: AppTheme.light(), home: const CourseInfoPage())));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('어떤 코스를 만들까요?'), findsOneWidget);
    expect(find.text('출발 시간'), findsOneWidget);
    expect(find.text('여행 분위기'), findsNothing);
    expect(find.text('선택한 분위기는 추천에 반영돼요.'), findsNothing);
  });
}
