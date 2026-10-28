import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/states.dart';
import '../../../place/domain/place.dart';
import '../../domain/course_models.dart';
import 'course_place_row.dart';
import 'course_route_map.dart';

/// 코스 머리: 이름 + 한 줄 정보 (상세 · 4단계 결과 · 편집이 같은 모양)
class CourseHero extends StatelessWidget {
  const CourseHero({super.key, required this.title, required this.meta, this.dday, this.savedNotice = false});

  final String title;
  final String meta;

  /// 다가오는 코스의 D-day (날짜에서 계산한 값)
  final String? dday;

  /// 저장하고 바로 들어왔을 때만 보이는 "코스가 저장되었어요"
  final bool savedNotice;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xxs, AppSpacing.screenH, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (savedNotice) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
              decoration: BoxDecoration(color: AppColors.successSoft, borderRadius: AppRadius.pillAll),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_rounded, size: 14, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text('코스가 저장되었어요', style: AppTypography.caption.copyWith(color: AppColors.success, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (dday != null) ...[
            Text(dday!, style: AppTypography.label.copyWith(color: AppColors.primary)),
            const SizedBox(height: 2),
          ],
          Text(title, style: AppTypography.title.copyWith(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(meta, style: AppTypography.meta),
        ],
      ),
    );
  }
}

/// "10월 22일 (목) · 오전 11:00 출발 · 5곳 · 약 6시간"
String courseMetaLine({DateTime? date, TimeOfDay? start, int? placeCount, Duration? duration}) => [
      if (date != null) formatMonthDayWeekday(date),
      if (start != null) '${formatTimeOfDay(start)} 출발',
      if (placeCount != null) '$placeCount곳',
      if (duration != null) '약 ${formatDuration(duration)}',
    ].join(' · ');

/// 일정 카드 제목 줄의 "편집" 버튼 (테두리 있는 작은 버튼, 누르는 영역 44)
class CourseEditButton extends StatelessWidget {
  const CourseEditButton({super.key, required this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: Material(
        color: AppColors.surfaceRaised,
        shape: const StadiumBorder(side: BorderSide(color: AppColors.border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32, minWidth: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.edit_outlined, size: 14, color: AppColors.textPrimary),
                  const SizedBox(width: 4),
                  Text('편집', style: AppTypography.meta.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 장소 번호 원. 내가 고른 장소 = 진한 번호, AI 추천 = 주황 ✦.
Widget _marker(CourseStop stop, int? number) => StopMarker(source: stop.source, number: number, size: 26, dark: !stop.isAi);

/// 장소 이름 아래 줄. AI 추천은 "✦ 이유"(주황 글자), 내가 고른 장소는 카테고리 · 지역.
class _StopText extends StatelessWidget {
  const _StopText({required this.stop, this.prefix});
  final CourseStop stop;
  final String? prefix;

  @override
  Widget build(BuildContext context) {
    final place = stop.place;
    final area = _shortArea(place);
    final sub = stop.isAi ? '✦ ${stop.aiReason ?? 'AI 추천'}' : [place.categoryLabel, if (area.isNotEmpty) area].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(place.name, style: AppTypography.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 1),
        Text.rich(
          TextSpan(children: [
            if (prefix != null)
              TextSpan(text: '$prefix · ', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
            TextSpan(text: sub),
          ]),
          style: AppTypography.caption.copyWith(
            color: stop.isAi ? AppColors.aiText : null,
            fontWeight: stop.isAi ? FontWeight.w700 : null,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// '서울 성동구 성수동' → '성수동'
String _shortArea(Place p) {
  final parts = p.displayArea.trim().split(RegExp(r'\s+'));
  return parts.isEmpty ? '' : parts.last;
}

/// 일정 타임라인 (보는 상태). 장소 행은 옅은 흰 바탕으로 나누고, 행 사이 점선에 이동 정보를 둔다.
/// 코스 상세와 4단계 결과가 같은 위젯을 쓴다.
class CourseTimeline extends StatelessWidget {
  const CourseTimeline({
    super.key,
    required this.stops,
    this.onTapStop,
    this.onMore,
    this.highlightIds = const {},
    this.loadingIds = const {},
  });

  final List<CourseStop> stops;
  final void Function(CourseStop stop, int index)? onTapStop;

  /// AI 장소 행 끝의 ⋯ (없으면 표시하지 않음)
  final void Function(CourseStop stop, int index)? onMore;

  /// 다시 추천으로 바뀐 장소 (주황 바탕)
  final Set<String> highlightIds;

  /// 다시 추천 중인 자리 (뼈대)
  final Set<String> loadingIds;

  @override
  Widget build(BuildContext context) {
    final numbers = userStopNumbers(stops);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < stops.length; i++) ...[
            if (loadingIds.contains(stops[i].place.id))
              const _SkeletonTile(withTime: true)
            else
              _ViewTile(
                stop: stops[i],
                number: numbers[i],
                highlighted: highlightIds.contains(stops[i].place.id),
                onTap: onTapStop == null ? null : () => onTapStop!(stops[i], i),
                onMore: onMore == null || !stops[i].isAi ? null : () => onMore!(stops[i], i),
              ),
            if (i < stops.length - 1) _LegRow(leg: stops[i].nextLeg),
          ],
        ],
      ),
    );
  }
}

class _ViewTile extends StatelessWidget {
  const _ViewTile({required this.stop, required this.number, this.highlighted = false, this.onTap, this.onMore});
  final CourseStop stop;
  final int? number;
  final bool highlighted;
  final VoidCallback? onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted ? AppColors.aiSoft : AppColors.surfaceRaised,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.xs, 8, onMore == null ? AppSpacing.sm : 0, 8),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    stop.arrivalTime == null ? '' : formatClock(stop.arrivalTime!),
                    textAlign: TextAlign.right,
                    style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                _marker(stop, number),
                const SizedBox(width: 10),
                Expanded(child: _StopText(stop: stop)),
                if (onMore != null)
                  IconButton(
                    tooltip: '${stop.place.name} 메뉴',
                    onPressed: onMore,
                    icon: const Icon(Icons.more_horiz_rounded, size: 20, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 장소 사이 이동 줄: 번호 원 아래 점선 + "도보 6분"
class _LegRow extends StatelessWidget {
  const _LegRow({this.leg});
  final RouteLeg? leg;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: Row(
        children: [
          // 시각(40) + 간격(8) + 번호 원 가운데(13)
          const SizedBox(width: AppSpacing.xs + 40 + AppSpacing.xs + 12),
          CustomPaint(size: const Size(2, 30), painter: _DashPainter()),
          const SizedBox(width: 14),
          if (leg != null) ...[
            Icon(leg!.mode.icon, size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(leg!.label, style: AppTypography.caption),
          ],
        ],
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.controlBorder
      ..strokeWidth = 1.5;
    for (double y = 2; y < size.height - 2; y += 5) {
      canvas.drawLine(Offset(size.width / 2, y), Offset(size.width / 2, y + 2.5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile({this.withTime = false});
  final bool withTime;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 8),
      decoration: BoxDecoration(color: AppColors.surfaceRaised, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          if (withTime) ...[
            const SizedBox(width: 40, child: Align(alignment: Alignment.centerRight, child: SkeletonBox(width: 30, height: 10, radius: 5))),
            const SizedBox(width: AppSpacing.xs),
          ] else
            const SizedBox(width: 24),
          const SkeletonBox(width: 26, height: 26, radius: 13),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(widthFactor: 0.6, child: SkeletonBox(height: 11, radius: 5)),
                SizedBox(height: 6),
                FractionallySizedBox(widthFactor: 0.35, child: SkeletonBox(height: 9, radius: 5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 일정 편집 목록 (손잡이 · 번호 · 이름 · X, 마지막 "장소 추가").
/// 시간과 이동 줄은 저장하거나 다시 추천하면 다시 계산되므로 편집 중에는 숨긴다.
class CourseEditList extends StatelessWidget {
  const CourseEditList({
    super.key,
    required this.stops,
    required this.onReorder,
    required this.onRemove,
    required this.onTapTile,
    this.onAdd,
    this.addedIds = const {},
    this.highlightIds = const {},
    this.loadingIds = const {},
    this.enabled = true,
  });

  final List<CourseStop> stops;
  final void Function(int oldIndex, int newIndex) onReorder;

  /// X — 언제나 "이번만" 빼기 (차단은 타일 시트에서만)
  final void Function(CourseStop stop) onRemove;
  final void Function(CourseStop stop, int index) onTapTile;
  final VoidCallback? onAdd;

  /// 방금 넣은 장소 (파란 테두리 + "새로 추가")
  final Set<String> addedIds;
  final Set<String> highlightIds;
  final Set<String> loadingIds;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final numbers = userStopNumbers(stops);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: stops.length,
            onReorder: enabled ? onReorder : (_, _) {},
            proxyDecorator: (child, _, _) => Material(
              color: Colors.transparent,
              elevation: 6,
              shadowColor: const Color(0x2914223A),
              borderRadius: BorderRadius.circular(14),
              child: child,
            ),
            itemBuilder: (_, i) {
              final stop = stops[i];
              final id = stop.place.id;
              return Padding(
                key: ValueKey(id),
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: loadingIds.contains(id)
                    ? const _SkeletonTile()
                    : _EditTile(
                        stop: stop,
                        index: i,
                        number: numbers[i],
                        added: addedIds.contains(id),
                        highlighted: highlightIds.contains(id),
                        enabled: enabled,
                        onRemove: () => onRemove(stop),
                        onTap: () => onTapTile(stop, i),
                      ),
              );
            },
          ),
          if (onAdd != null) _AddTile(onTap: enabled ? onAdd : null),
        ],
      ),
    );
  }
}

class _EditTile extends StatelessWidget {
  const _EditTile({
    required this.stop,
    required this.index,
    required this.number,
    required this.added,
    required this.highlighted,
    required this.enabled,
    required this.onRemove,
    required this.onTap,
  });

  final CourseStop stop;
  final int index;
  final int? number;
  final bool added;
  final bool highlighted;
  final bool enabled;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return Material(
      color: highlighted ? AppColors.aiSoft : AppColors.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: added ? const BorderSide(color: AppColors.primary, width: 1.5) : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: enabled ? onTap : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                enabled: enabled,
                child: const SizedBox(
                  width: 40,
                  height: 56,
                  child: Icon(Icons.drag_handle_rounded, color: AppColors.controlBorder, semanticLabel: '끌어서 순서 변경'),
                ),
              ),
              _marker(stop, number),
              const SizedBox(width: 10),
              Expanded(child: _StopText(stop: stop, prefix: added ? '새로 추가' : null)),
              IconButton(
                tooltip: '${stop.place.name} 빼기',
                onPressed: enabled ? onRemove : null,
                icon: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(color: AppColors.surfaceMuted, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            height: 52,
            child: Row(
              children: [
                const SizedBox(width: 40),
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                  child: const Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Text('장소 추가', style: AppTypography.bodyStrong.copyWith(color: AppColors.primary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.controlBorder.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14)));
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
