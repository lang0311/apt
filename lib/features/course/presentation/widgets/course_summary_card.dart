import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/surfaces.dart';
import '../../domain/course_models.dart';

/// 코스 목록 카드 (썸네일 · 제목 · 지역/장소 수/인원 · 날짜 또는 상태)
class CourseSummaryCard extends StatelessWidget {
  const CourseSummaryCard({super.key, required this.course, required this.onTap});
  final CourseSummary course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = [
      ?course.regionLabel,
      '${course.placeCount}곳',
      if (course.isParty) '${course.memberCount}명',
    ].join(' · ');
    final highlight = course.isParty ? (course.statusLabel ?? (course.date == null ? null : formatDate(course.date!))) : (course.date == null ? null : formatDate(course.date!));

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          AppNetworkImage(url: course.thumbnailUrl, width: 72, height: 72, radius: AppRadius.thumb),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(course.title, style: AppTypography.cardTitle.copyWith(fontSize: 17), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(meta, style: AppTypography.meta),
                if (highlight != null) ...[
                  const SizedBox(height: 4),
                  Text(highlight, style: AppTypography.bodyStrong.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                ],
              ],
            ),
          ),
          Icon(
            course.bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            color: AppColors.textSecondary,
            semanticLabel: course.bookmarked ? '북마크됨' : null,
          ),
        ],
      ),
    );
  }
}
