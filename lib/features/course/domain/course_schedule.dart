import 'package:flutter/material.dart';

import '../../place/domain/place.dart';
import 'course_models.dart';

/// 서버가 추천할 때 계산한 예상 일정 (`taste_profile.route_optimization.estimated_schedule`, 팀 c29137a).
/// 추천 당시 순서 기준이라, 순서 · 장소 · 출발 시간이 그대로일 때만 쓴다 (21번)
class EstimatedSchedule {
  const EstimatedSchedule({required this.start, required this.stops, this.usedDefaultStart = false});

  /// 서버가 계산에 쓴 출발 시간
  final TimeOfDay start;

  /// 장소 이름과 예상 도착 시각 (서버 순서)
  final List<({String name, TimeOfDay arrival})> stops;

  /// 출발 시간이 없어 서버가 12:00으로 가정했는지. 사용자가 정하지 않은 시각이라 보여 주지 않는다
  final bool usedDefaultStart;
}

/// 일정에 예상 도착 시각과 다음 장소까지 직선거리를 붙인다 (21번, A안 · ②안).
///
/// - 시각: 순서 · 출발 시간이 서버 일정과 같으면 서버 값 그대로, 다르면(편집 · 다시 추천 · 예전 코스) 서버와 같은 규칙으로 앱이 계산.
///   출발 시간이 없거나 서버가 12:00을 가정했거나 좌표가 없는 장소가 있으면 모두 비운다(시간 칸이 접힌다).
/// - 이동 줄: 두 장소에 좌표가 있으면 직선거리. 화면에 보일 때마다 지금 순서로 다시 계산하므로 편집해도 맞는다.
List<CourseStop> withEstimatedTimes(List<CourseStop> stops, {TimeOfDay? start, EstimatedSchedule? server}) {
  final arrivals = _arrivals(stops, start, server);
  return [
    for (var i = 0; i < stops.length; i++)
      CourseStop(
        place: stops[i].place,
        source: stops[i].source,
        aiReason: stops[i].aiReason,
        evidence: stops[i].evidence,
        arrivalTime: arrivals?[i],
        nextLeg: i == stops.length - 1 ? null : _straight(stops[i].place, stops[i + 1].place),
      ),
  ];
}

RouteLeg? _straight(Place from, Place to) {
  final a = from.location, b = to.location;
  return a == null || b == null ? null : RouteLeg.straight(a.distanceTo(b));
}

List<TimeOfDay>? _arrivals(List<CourseStop> stops, TimeOfDay? start, EstimatedSchedule? server) {
  if (start == null || stops.isEmpty || server?.usedDefaultStart == true) return null;
  if (server != null && _sameAsServer(stops, start, server)) return [for (final s in server.stops) s.arrival];
  if (stops.any((s) => s.place.location == null)) return null;
  // 서버 day_course.py optimize_day_order와 같은 계산: 출발 → (머묾 → 직선 1km당 15분 이동) 반복, 분 단위 버림
  var minute = start.hour * 60.0 + start.minute;
  final result = <TimeOfDay>[];
  for (var i = 0; i < stops.length; i++) {
    if (i > 0) minute += stops[i - 1].place.location!.distanceTo(stops[i].place.location!) / 1000 * 15;
    final whole = minute.floor();
    result.add(TimeOfDay(hour: (whole ~/ 60) % 24, minute: whole % 60));
    minute += stayMinutes(stops[i].place);
  }
  return result;
}

bool _sameAsServer(List<CourseStop> stops, TimeOfDay start, EstimatedSchedule server) =>
    server.start == start &&
    server.stops.length == stops.length &&
    [for (var i = 0; i < stops.length; i++) server.stops[i].name == stops[i].place.name].every((same) => same);

/// 한 장소에 머문다고 보는 시간(분). 서버 `day_course.py`의 is_meal · is_cafe · is_bar 규칙을 그대로 옮겼다:
/// 식당 · 술집 60분, 카페 45분, 그 밖 75분. 카테고리는 서버가 준 문자열(`음식점 > 카페 > …`)로 판단한다
int stayMinutes(Place place) {
  final category = place.categoryKey;
  final lower = category.toLowerCase();
  final bar = const ['술집', '주점', '칵테일', '와인바', '이자카야', '맥주', '펍'].any(category.contains) ||
      RegExp(r'\b(bar|pub|night_club)\b').hasMatch(lower);
  final cafe = const ['카페', '간식', '베이커리', '제과', '디저트', 'cafe', 'bakery'].any(category.contains);
  final meal = (category.contains('음식') || category.contains('restaurant')) && !cafe && !bar;
  if (meal || bar) return 60;
  if (cafe) return 45;
  return 75;
}
