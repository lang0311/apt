import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/selection.dart';
import '../../../../core/widgets/surfaces.dart';
import '../../domain/course_models.dart';

/// 코스 장소 번호 원 — 선택 장소는 파랑 번호, AI 추천은 주황 ✦ (항상 구분)
class StopMarker extends StatelessWidget {
  const StopMarker({super.key, required this.source, this.number, this.size = 28, this.dark = false});
  final PlaceSource source;
  final int? number;
  final double size;

  /// 코스 상세 일정의 진한 번호 원
  final bool dark;

  @override
  Widget build(BuildContext context) {
    if (source == PlaceSource.ai) {
      return Semantics(
        label: 'AI 추천',
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: dark ? AppColors.aiSoft : AppColors.ai, shape: BoxShape.circle),
          child: Icon(Icons.auto_awesome, size: size * 0.5, color: dark ? AppColors.ai : Colors.white),
        ),
      );
    }
    return NumberBadge(number ?? 0, size: size, color: dark ? AppColors.ink : AppColors.primary);
  }
}

/// 코스 장소 행 (드래그 핸들 · 번호/✦ · 썸네일 · 이름 · 부제 · 액션)
class CoursePlaceRow extends StatelessWidget {
  const CoursePlaceRow({
    super.key,
    required this.stopName,
    required this.imageUrl,
    required this.source,
    this.number,
    required this.subtitle,
    this.subtitleColor,
    this.dragHandle,
    this.trailing,
    this.onTap,
  });

  final String stopName;
  final String? imageUrl;
  final PlaceSource source;
  final int? number;
  final String subtitle;
  final Color? subtitleColor;

  /// ReorderableDragStartListener로 감싼 핸들 (순서 변경 가능할 때만)
  final Widget? dragHandle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      child: Row(
        children: [
          ?dragHandle,
          StopMarker(source: source, number: number),
          const SizedBox(width: AppSpacing.sm),
          AppNetworkImage(url: imageUrl, width: 56, height: 56, radius: 12),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stopName, style: AppTypography.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.meta.copyWith(
                    color: subtitleColor,
                    fontWeight: subtitleColor == null ? null : FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class DragHandle extends StatelessWidget {
  const DragHandle({super.key, required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return ReorderableDragStartListener(
      index: index,
      child: const Padding(
        padding: EdgeInsets.only(right: AppSpacing.xs),
        child: Icon(Icons.drag_handle_rounded, color: AppColors.textSecondary, semanticLabel: '끌어서 순서 변경'),
      ),
    );
  }
}
