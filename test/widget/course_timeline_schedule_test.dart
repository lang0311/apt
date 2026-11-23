import 'package:apt/app/theme/app_theme.dart';
import 'package:apt/core/models/geo_point.dart';
import 'package:apt/features/course/domain/course_models.dart';
import 'package:apt/features/course/domain/course_schedule.dart';
import 'package:apt/features/course/presentation/widgets/course_timeline.dart';
import 'package:apt/features/place/domain/place.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

CourseStop _stop(String name, String category, double lat) => CourseStop(
  place: Place(id: name, name: name, address: '서울 성동구 성수동', categoryKey: category, categoryLabel: category, location: GeoPoint(lat, 127.0)),
  source: PlaceSource.user,
);

/// 21번 A안: 번호 왼쪽 예상 도착 시각 + 장소 사이 `약 1.0km` 이동 줄
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('예상 시각과 직선거리 이동 줄을 보여 주고 360 · 1.3배에서 넘치지 않는다', (tester) async {
    final stops = withEstimatedTimes(
      [_stop('카페', '음식점 > 카페', 37.500), _stop('식당', '음식점 > 한식', 37.509)],
      start: const TimeOfDay(hour: 12, minute: 0),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(size: Size(360, 640), textScaler: TextScaler.linear(1.3)),
          child: Scaffold(body: SingleChildScrollView(child: CourseTimeline(stops: stops))),
        ),
      ),
    );

    expect(find.text('12:00'), findsOneWidget);
    expect(find.text('예상'), findsOneWidget);
    expect(find.text('13:00'), findsOneWidget);
    expect(find.text('약 1.0km'), findsOneWidget);
    expect(find.byIcon(LucideIcons.moveHorizontal), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('출발 시간이 없으면 시간 칸은 접히고 거리 줄만 남는다', (tester) async {
    final stops = withEstimatedTimes([_stop('카페', '음식점 > 카페', 37.500), _stop('식당', '음식점 > 한식', 37.509)]);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: Scaffold(body: CourseTimeline(stops: stops))));

    expect(find.text('예상'), findsNothing);
    expect(find.text('약 1.0km'), findsOneWidget);
  });
}
