import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/map/apt_map.dart';
import '../../../../core/widgets/map/map_pin.dart';
import '../../domain/course_models.dart';

/// 코스 동선 지도: 선택 장소 = 번호 핀, AI 추천 = 주황 ✦ 핀, 순서대로 경로선.
/// 경로선은 도로를 따르는 polyline이 의도 — 데이터 제공 주체는 미정 (NEEDS BACKEND).
class CourseRouteMap extends StatelessWidget {
  const CourseRouteMap({super.key, required this.stops, this.height = 220});
  final List<CourseStop> stops;
  final double height;

  @override
  Widget build(BuildContext context) {
    var userNo = 0;
    final markers = <MapMarker>[];
    for (final s in stops) {
      if (s.place.location == null) continue;
      if (s.isAi) {
        markers.add(MapMarker(id: s.place.id, point: s.place.location!, kind: MapPinKind.ai));
      } else {
        markers.add(MapMarker(id: s.place.id, point: s.place.location!, kind: MapPinKind.numbered, number: ++userNo));
      }
    }
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: AptMap(
          markers: markers,
          route: [for (final s in stops) ?s.place.location],
        ),
      ),
    );
  }
}

/// 선택 장소만 순번을 매긴다 (AI 추천은 ✦)
List<int?> userStopNumbers(List<CourseStop> stops) {
  var n = 0;
  return [for (final s in stops) s.isAi ? null : ++n];
}
