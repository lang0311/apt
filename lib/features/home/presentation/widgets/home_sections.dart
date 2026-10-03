import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/instagram_url.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/chips.dart';
import '../../../../core/widgets/surfaces.dart';
import '../../../course/domain/course_models.dart';
import '../../../extraction/domain/extraction_models.dart';
import '../../../place/domain/place.dart';
import '../../domain/home_models.dart';

/// 통계 3타일 (저장된 장소 · 진행 중인 코스 · 최근 추출) — 각 탭으로 이동
class HomeStatsCard extends StatelessWidget {
  const HomeStatsCard({super.key, required this.stats});
  final HomeStats stats;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.xs),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _Stat(
                icon: Icons.bookmark_border_rounded,
                color: AppColors.primary,
                background: AppColors.primarySoft,
                label: '저장된 장소',
                value: stats.savedPlaceCount,
                onTap: () => context.go(AppRoutes.saved),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: _Stat(
                icon: Icons.map_outlined,
                color: AppColors.success,
                background: AppColors.successSoft,
                label: '진행 중인 코스',
                value: stats.activeCourseCount,
                onTap: () => context.go(AppRoutes.courses),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: _Stat(
                icon: Icons.link_rounded,
                color: AppColors.extract,
                background: AppColors.extractSoft,
                label: '최근 추출',
                value: stats.recentExtractionCount,
                caption: stats.recentExtractionPeriodLabel,
                onTap: () => context.go(AppRoutes.extract),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.color,
    required this.background,
    required this.label,
    required this.value,
    required this.onTap,
    this.caption,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String label;
  final int value;
  final String? caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label $value',
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconCircle(icon: icon, size: 34, color: color, background: background),
              const SizedBox(height: AppSpacing.xs),
              Text(label, style: AppTypography.caption.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700), maxLines: 1),
              Row(
                children: [
                  Text('$value', style: AppTypography.statNumber),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                ],
              ),
              if (caption != null) Text(caption!, style: AppTypography.caption),
            ],
          ),
        ),
      ),
    );
  }
}

/// 최근 추출한 장소 카드
class RecentExtractionCard extends StatelessWidget {
  const RecentExtractionCard({super.key, required this.item, required this.onSave});
  final RecentExtraction item;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final p = item.place;
    return AppCard(
      onTap: () => context.push(AppRoutes.place(p.id)),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          AppNetworkImage(url: p.imageUrl, width: 84, height: 84, radius: 14),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.camera_alt_outlined, size: 14, color: Color(0xFFC13584)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        InstagramUrl.shortLabel(item.sourceUrl, maxLength: 22),
                        style: AppTypography.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text('${formatRelative(item.extractedAt)} 추출', style: AppTypography.caption),
                  ],
                ),
                const SizedBox(height: 4),
                Text(p.name, style: AppTypography.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(p.address, style: AppTypography.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: TagWrap(p.keywords, max: 3)),
                    const SizedBox(width: AppSpacing.xs),
                    // 저장됨은 상태 표시(비활성 버튼처럼 흐리게 보이지 않게), 저장하기만 버튼
                    p.isSaved
                        ? Container(
                            height: 34,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(AppRadius.sm)),
                            child: Text('저장됨', style: AppTypography.label.copyWith(color: AppColors.primary)),
                          )
                        : AppButton(
                            label: '저장하기',
                            variant: AppButtonVariant.soft,
                            expand: false,
                            height: 34,
                            onPressed: onSave,
                          ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 지금 뜨는 장소 (가로 카드)
class TrendingPlaceCard extends StatelessWidget {
  const TrendingPlaceCard({super.key, required this.place});
  final Place place;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 148,
      child: AppCard(
        onTap: () => context.push(AppRoutes.place(place.id)),
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AppNetworkImage(url: place.imageUrl, width: double.infinity, height: 92, radius: 14),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Icon(
                    place.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: Colors.white,
                    shadows: const [Shadow(color: Color(0x6614223A), blurRadius: 6)],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, AppSpacing.xs, 4, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.name, style: AppTypography.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(place.displayArea, style: AppTypography.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.ai, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      // 트렌디함은 서버(LLM) 판단 → AI 강조색 사용
                      Text('지금 인기', style: AppTypography.caption.copyWith(color: AppColors.ai, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 내 코스 바로가기
class ActiveCourseCard extends StatelessWidget {
  const ActiveCourseCard({super.key, required this.course});
  final CourseSummary course;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push(AppRoutes.course(course.id)),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          AppNetworkImage(url: course.thumbnailUrl, width: 84, height: 84, radius: 14),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(course.title, style: AppTypography.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  ['장소 ${course.placeCount}곳', if (course.date != null) formatDate(course.date!)].join(' · '),
                  style: AppTypography.meta,
                ),
                const SizedBox(height: 6),
                TagWrap(course.tags, max: 3),
              ],
            ),
          ),
          AppButton(
            label: '이어보기',
            variant: AppButtonVariant.soft,
            expand: false,
            height: 40,
            onPressed: () => context.push(AppRoutes.course(course.id)),
          ),
        ],
      ),
    );
  }
}
