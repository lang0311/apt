import 'package:apt/app/theme/app_theme.dart';
import 'package:apt/core/widgets/app_network_image.dart';
import 'package:apt/features/course/domain/course_models.dart';
import 'package:apt/features/course/presentation/widgets/course_thumb.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: Center(child: child)),
);

CourseSummary _course({String? thumbnailUrl, List<String> keys = const []}) =>
    CourseSummary(id: 'c1', title: 'test3', placeCount: keys.length, thumbnailUrl: thumbnailUrl, stopCategoryKeys: keys);

void main() {
  testWidgets('사진이 없으면 장소 카테고리 아이콘을 2×2로 모은다', (tester) async {
    final course = _course(keys: const ['음식점 > 한식', '여행 > 공원', '음식점 > 카페 > 디저트카페', '여행 > 공원']);
    await tester.pumpWidget(_wrap(CourseThumb(course: course)));

    expect(find.byType(AppNetworkImage), findsNothing);
    expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);
    expect(find.byIcon(Icons.local_cafe_rounded), findsOneWidget);
    expect(find.byIcon(Icons.landscape_rounded), findsNWidgets(2));
  });

  testWidgets('사진 주소가 있으면 사진 칸을 쓴다', (tester) async {
    await tester.pumpWidget(
      _wrap(
        CourseThumb(
          course: _course(thumbnailUrl: 'https://example.com/a.jpg', keys: const ['음식점 > 한식']),
        ),
      ),
    );
    expect(find.byType(AppNetworkImage), findsOneWidget);
  });

  testWidgets('장소 정보가 아무것도 없으면 기존 자리표시 칸을 쓴다', (tester) async {
    await tester.pumpWidget(_wrap(CourseThumb(course: _course())));
    expect(find.byType(AppNetworkImage), findsOneWidget);
  });

  testWidgets('장소가 4개보다 적으면 남는 칸은 빈 칸으로 둔다', (tester) async {
    await tester.pumpWidget(_wrap(CourseThumb(course: _course(keys: const ['음식점 > 한식']))));
    expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
