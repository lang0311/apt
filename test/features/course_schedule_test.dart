import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apt/core/models/geo_point.dart';
import 'package:apt/features/course/domain/course_models.dart';
import 'package:apt/features/course/domain/course_schedule.dart';
import 'package:apt/features/place/domain/place.dart';

// 위도 0.009° ≈ 1,000.8m → 서버 규칙(직선 1km당 15분)으로 약 15분
CourseStop stop(String name, String category, double lat) => CourseStop(
  place: Place(id: name, name: name, address: '서울', categoryKey: category, categoryLabel: category, location: GeoPoint(lat, 127.0)),
  source: PlaceSource.user,
);

final cafe = stop('카페', '음식점 > 카페 > 커피전문점', 37.500);
final meal = stop('식당', '음식점 > 한식', 37.509);
final park = stop('공원', '여행 > 공원', 37.518);
const noon = TimeOfDay(hour: 12, minute: 0);

void main() {
  group('머무는 시간 (서버 day_course.py와 같은 규칙)', () {
    test('카페 45분 · 식당 60분 · 술집 60분 · 그 밖 75분', () {
      expect(stayMinutes(cafe.place), 45);
      expect(stayMinutes(meal.place), 60);
      expect(stayMinutes(stop('바', '음식점 > 술집 > 호프,요프', 0).place), 60);
      expect(stayMinutes(park.place), 75);
    });
  });

  group('예상 도착 시각', () {
    test('순서가 서버 일정과 같으면 서버 시각을 그대로 쓴다', () {
      const server = EstimatedSchedule(start: noon, stops: [
        (name: '카페', arrival: TimeOfDay(hour: 12, minute: 0)),
        (name: '식당', arrival: TimeOfDay(hour: 13, minute: 7)),
      ]);
      final result = withEstimatedTimes([cafe, meal], start: noon, server: server);
      expect(result.map((s) => s.arrivalTime), [noon, const TimeOfDay(hour: 13, minute: 7)]);
    });

    test('순서가 바뀌면 같은 규칙으로 앱이 다시 계산한다', () {
      const server = EstimatedSchedule(start: noon, stops: [
        (name: '카페', arrival: TimeOfDay(hour: 12, minute: 0)),
        (name: '식당', arrival: TimeOfDay(hour: 13, minute: 7)),
      ]);
      // 식당 12:00 + 머묾 60분 + 이동 약 15분 → 카페 13:15
      final result = withEstimatedTimes([meal, cafe], start: noon, server: server);
      expect(result.map((s) => s.arrivalTime), [noon, const TimeOfDay(hour: 13, minute: 15)]);
    });

    test('출발 시간을 바꿔 저장하면 서버 시각 대신 다시 계산한다', () {
      const server = EstimatedSchedule(start: noon, stops: [
        (name: '카페', arrival: TimeOfDay(hour: 12, minute: 0)),
        (name: '식당', arrival: TimeOfDay(hour: 13, minute: 7)),
      ]);
      final result = withEstimatedTimes([cafe, meal], start: const TimeOfDay(hour: 14, minute: 0), server: server);
      expect(result.map((s) => s.arrivalTime), [const TimeOfDay(hour: 14, minute: 0), const TimeOfDay(hour: 15, minute: 0)]);
    });

    test('서버 일정이 없는 예전 코스도 출발 시간이 있으면 계산한다', () {
      final result = withEstimatedTimes([cafe, meal, park], start: noon);
      // 카페 12:00 +45 +15 → 식당 13:00 +60 +15 → 공원 14:15
      expect(result.map((s) => s.arrivalTime), [noon, const TimeOfDay(hour: 13, minute: 0), const TimeOfDay(hour: 14, minute: 15)]);
    });

    test('서버가 출발 시간을 12:00으로 가정한 코스는 시각을 보여 주지 않는다', () {
      const server = EstimatedSchedule(start: noon, usedDefaultStart: true, stops: [
        (name: '카페', arrival: TimeOfDay(hour: 12, minute: 0)),
        (name: '식당', arrival: TimeOfDay(hour: 13, minute: 7)),
      ]);
      final result = withEstimatedTimes([cafe, meal], start: noon, server: server);
      expect(result.every((s) => s.arrivalTime == null), isTrue);
    });

    test('출발 시간이 없으면 시각을 보여 주지 않는다', () {
      final result = withEstimatedTimes([cafe, meal], start: null);
      expect(result.every((s) => s.arrivalTime == null), isTrue);
    });

    test('좌표가 없는 장소가 있으면 시각을 보여 주지 않는다', () {
      final noPlace = CourseStop(
        place: const Place(id: 'x', name: '어딘가', address: '서울', categoryKey: '', categoryLabel: ''),
        source: PlaceSource.ai,
      );
      final result = withEstimatedTimes([cafe, noPlace, meal], start: noon);
      expect(result.every((s) => s.arrivalTime == null), isTrue);
    });
  });

  group('장소 사이 직선거리 (A안)', () {
    test('다음 장소까지 거리를 이동 줄로 붙이고 마지막 장소에는 없다', () {
      final result = withEstimatedTimes([cafe, meal, park], start: null);
      expect(result.map((s) => s.nextLeg?.label), ['약 1.0km', '약 1.0km', null]);
    });

    test('좌표가 없는 구간만 이동 줄을 뺀다', () {
      final noPlace = CourseStop(
        place: const Place(id: 'x', name: '어딘가', address: '서울', categoryKey: '', categoryLabel: ''),
        source: PlaceSource.ai,
      );
      final result = withEstimatedTimes([cafe, meal, noPlace], start: noon);
      expect(result.map((s) => s.nextLeg?.label), ['약 1.0km', null, null]);
    });

    test('1km 미만은 100m 단위, 100m 미만은 10m 단위, 1km 이상은 0.1km 단위', () {
      expect(RouteLeg.straight(512).label, '약 500m');
      expect(RouteLeg.straight(46).label, '약 50m');
      expect(RouteLeg.straight(4).label, '약 10m');
      expect(RouteLeg.straight(960).label, '약 1.0km');
      expect(RouteLeg.straight(1234).label, '약 1.2km');
    });
  });
}
