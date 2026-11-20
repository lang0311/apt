import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/map/apt_map.dart';
import '../../../../core/widgets/map/map_pin.dart';
import '../../domain/course_models.dart';
import '../pages/course_route_map_page.dart';

/// 코스 동선 지도: 선택 장소 = 번호 핀, AI 추천 = 주황 ✦ 핀, 순서대로 경로선.
/// 경로선은 도로를 따르는 polyline이 의도 — 데이터 제공 주체는 미정 (NEEDS BACKEND).
/// 지도를 누르면 전체 화면 지도([CourseRouteMapPage])가 열린다.
class CourseRouteMap extends StatelessWidget {
  const CourseRouteMap({super.key, required this.title, required this.stops, required this.height});

  /// 전체 화면 지도 위에 보이는 코스 이름
  final String title;
  final List<CourseStop> stops;
  final double height;

  @override
  Widget build(BuildContext context) {
    var userNo = 0;
    final markers = <MapMarker>[];
    for (final s in stops) {
      if (s.place.location == null) continue;
      // 번호는 일정 순서 그대로(AI 추천 곳 포함), AI 추천은 주황 번호 + ✦
      markers.add(
        MapMarker(id: s.place.id, point: s.place.location!, kind: s.isAi ? MapPinKind.ai : MapPinKind.numbered, number: ++userNo),
      );
    }
    final canOpen = markers.isNotEmpty;
    void open() => context.push(
      AppRoutes.courseMap,
      extra: CourseMapArgs(title: title, stops: stops),
    );
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Stack(
          children: [
            Positioned.fill(
              child: AptMap(markers: markers, route: [for (final s in stops) ?s.place.location]),
            ),
            // 작은 지도에서는 움직이지 않고, 어디를 눌러도 큰 지도가 열린다
            if (canOpen)
              Positioned.fill(
                child: Semantics(
                  button: true,
                  label: '코스 지도 크게 보기',
                  child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: open, child: const SizedBox.expand()),
                ),
              ),
            if (canOpen)
              Positioned(
                right: AppSpacing.xs + 2,
                bottom: AppSpacing.xs + 2,
                child: IgnorePointer(child: const _ExpandPill()),
              ),
          ],
        ),
      ),
    );
  }
}

/// 지도 오른쪽 아래 `크게 보기` 표시. 누르는 건 지도 전체가 받는다 (표시는 눌러도 되는 걸 알리는 용도)
class _ExpandPill extends StatelessWidget {
  const _ExpandPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.only(left: 10, right: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.open_in_full_rounded, size: 17, color: AppColors.textPrimary),
          const SizedBox(width: 6),
          Text('크게 보기', style: AppTypography.label.copyWith(color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

/// 일정 순번. AI 추천 곳도 번호를 매겨 1부터 끊기지 않게 한다 (색과 ✦로만 구분)
List<int> userStopNumbers(List<CourseStop> stops) => [for (var i = 0; i < stops.length; i++) i + 1];
