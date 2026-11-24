import 'package:apt/app/theme/app_colors.dart';
import 'package:apt/core/models/geo_point.dart';
import 'package:apt/features/course/domain/course_models.dart';
import 'package:apt/features/course/presentation/pages/course_route_map_page.dart';
import 'package:apt/features/course/presentation/widgets/course_route_map.dart';
import 'package:apt/features/place/domain/place.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Place _place(String id, double lat) =>
    Place(id: id, name: id, address: '', categoryKey: 'cafe', categoryLabel: '카페', location: GeoPoint(lat, 126.92));

void main() {
  testWidgets('전체 화면 코스 지도의 장소 카드는 AI 추천 곳 번호를 주황으로 구분한다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: CourseRouteMapPage(
        args: CourseMapArgs(title: '코스', stops: [
          CourseStop(place: _place('mine', 37.55), source: PlaceSource.user),
          CourseStop(place: _place('ai', 37.56), source: PlaceSource.ai),
        ]),
      ),
    ));
    await tester.pump();

    Color badgeColor(String number) {
      final badge = find.ancestor(
        of: find.descendant(of: find.byType(PageView), matching: find.text(number)),
        matching: find.byType(Container),
      );
      return ((tester.widget<Container>(badge.first).decoration! as BoxDecoration).color)!;
    }

    expect(badgeColor('1'), AppColors.primary);
    expect(badgeColor('2'), AppColors.ai);
  });

  test('위치 없는 곳이 끼어도 지도 번호는 일정 번호와 같다', () {
    final noLocation = Place(id: 'none', name: 'none', address: '', categoryKey: 'cafe', categoryLabel: '카페');
    final stops = [
      CourseStop(place: _place('a', 37.55), source: PlaceSource.user),
      CourseStop(place: noLocation, source: PlaceSource.user),
      CourseStop(place: _place('b', 37.56), source: PlaceSource.ai),
      CourseStop(place: _place('c', 37.57), source: PlaceSource.user),
    ];
    expect([for (final (s, n) in mappableStops(stops)) '${s.place.id}$n'], ['a1', 'b3', 'c4']);
  });
}
