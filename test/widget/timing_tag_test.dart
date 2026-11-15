import 'package:apt/features/course/domain/course_models.dart';
import 'package:apt/features/course/presentation/widgets/course_timeline.dart';
import 'package:apt/features/place/domain/place.dart';
import 'package:apt/features/place/domain/place_timing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 일정 줄의 팝업 · 신규 오픈 태그 (서버 API 1번). 날짜는 실행하는 날 기준으로 만든다
void main() {
  final today = DateTime.now();
  final d = DateTime(today.year, today.month, today.day);
  String md(DateTime x) => '${x.month}/${x.day}';

  CourseStop stop(String id, PlaceTiming? timing) => CourseStop(
        place: Place(id: id, name: '장소 $id', address: '서울 성동구 성수동1가', categoryKey: 'c', categoryLabel: '전시', timing: timing),
        source: PlaceSource.ai,
      );

  testWidgets('코스 날짜에 열려 있으면 끝 날짜, 먼저 끝나면 그 날짜에 종료', (tester) async {
    final end = d.add(const Duration(days: 7));
    final popup = PlaceTiming(kind: PlaceTimingKind.popup, start: d, end: end);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: CourseTimeline(stops: [stop('a', popup)], courseDate: d.add(const Duration(days: 3)))),
    ));
    expect(find.text('팝업 · ${md(end)}까지'), findsOneWidget);
    expect(find.text('전시 · 성수동1가'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: CourseTimeline(stops: [stop('a', popup)], courseDate: d.add(const Duration(days: 10)))),
    ));
    expect(find.text('팝업 · ${md(end)} 종료'), findsOneWidget);
  });

  testWidgets('신규 오픈은 날짜 없이, 일반 장소는 태그 없음', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CourseTimeline(stops: [
          stop('a', PlaceTiming(kind: PlaceTimingKind.newOpening, checkedOn: d)),
          stop('b', null),
        ]),
      ),
    ));
    expect(find.text('신규 오픈'), findsOneWidget);
    expect(find.textContaining('팝업'), findsNothing);
  });
}
