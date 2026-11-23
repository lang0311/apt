import 'package:apt/app/theme/app_theme.dart';
import 'package:apt/features/course/domain/course_models.dart';
import 'package:apt/features/home/presentation/widgets/home_sections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// 시안 v2 "9 홈 · 다가오는 코스": 연파랑 카드 + 번호 노선 + 아래 "n곳 · 직선 거리 · 코스 보기"
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final course = CourseSummary(
    id: 'c1',
    title: '성수 반나절 코스',
    placeCount: 5,
    date: DateTime.now().add(const Duration(days: 3)),
    isParty: true,
    memberCount: 3,
    distanceKm: 2.4,
    stopCategoryKeys: const ['cafe', 'park', 'culture', 'culture', 'food'],
    stopNames: const ['어니언 성수', '서울숲', '대림창고', '성수연방', '뚝섬 골목집'],
    stopIsAi: const [false, false, true, false, true],
  );

  Future<void> pump(WidgetTester tester, {double scale = 1, int more = 2}) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(size: const Size(360, 640), textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: HomeCourseCard(course: course, isToday: false, moreCount: more, onOpen: () {}, onMore: () {}),
          ),
        ),
      ),
    ),
  );

  testWidgets('정거장 번호 1~5, "함께 3명", 아래 "5곳 · 직선 2.4km"와 "코스 보기"', (tester) async {
    await pump(tester);
    for (final n in ['1', '2', '3', '4', '5']) {
      expect(find.text(n), findsOneWidget);
    }
    expect(find.text('함께 3명'), findsOneWidget);
    expect(find.text('5곳 · 직선 2.4km'), findsOneWidget);
    expect(find.text('코스 보기'), findsOneWidget);
    expect(find.text('다가오는 코스 2개 더'), findsOneWidget);
  });

  testWidgets('360 폭 · 글자 1.3배에서도 넘치지 않는다', (tester) async {
    await pump(tester, scale: 1.3);
    expect(tester.takeException(), isNull);
  });
}
