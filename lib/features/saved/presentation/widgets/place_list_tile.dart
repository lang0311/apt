import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/surfaces.dart';
import '../../../place/domain/place.dart';

/// 저장 장소 카드 행 (썸네일 · 이름 · 지역/카테고리 · ★평점 · 북마크/›)
class PlaceListTile extends StatelessWidget {
  const PlaceListTile({
    super.key,
    required this.place,
    this.onTap,
    this.subtitle,
    required this.footer,
    this.showBookmark = true,
    this.thumbSize = 68,
    this.flat = false,
  });

  final Place place;
  final VoidCallback? onTap;

  /// 기본: "지역 · 카테고리"
  final String? subtitle;

  /// 설명 아래 줄 (거리 등). 없으면 `SizedBox.shrink()`
  final Widget footer;

  final bool showBookmark;
  final double thumbSize;

  /// 카드 배경 없이 (바텀시트 목록)
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        AppNetworkImage(url: place.imageUrl, width: thumbSize, height: thumbSize, radius: AppRadius.thumb),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(place.name, style: AppTypography.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(
                subtitle ?? [if (place.shortArea.isNotEmpty) place.shortArea, place.categoryLabel].join(' · '),
                style: AppTypography.meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              footer,
            ],
          ),
        ),
        Column(
          children: [
            if (showBookmark)
              Icon(
                place.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: AppColors.primary,
                semanticLabel: place.isSaved ? '저장됨' : '저장 안 됨',
              ),
            const SizedBox(height: AppSpacing.xs),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ],
    );

    if (flat) {
      return InkWell(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm), child: content),
      );
    }
    return AppCard(onTap: onTap, padding: const EdgeInsets.all(AppSpacing.md), child: content);
  }
}
