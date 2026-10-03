import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/surfaces.dart';
import '../../domain/saved_models.dart';

/// 보관함 카드 (콜라주 썸네일 · 이름 · 장소 수 · 최근 업데이트)
class CollectionCard extends StatelessWidget {
  const CollectionCard({super.key, required this.collection, required this.onTap, this.onMore});

  final PlaceCollection collection;
  final VoidCallback onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          CollectionCollage(urls: collection.thumbnailUrls),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(collection.name, style: AppTypography.cardTitle.copyWith(fontSize: 17), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (onMore != null)
                      IconButton(
                        tooltip: '보관함 메뉴',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.more_horiz_rounded, color: AppColors.textHint),
                        onPressed: onMore,
                      ),
                  ],
                ),
                Text('장소 ${collection.placeCount}곳', style: AppTypography.meta),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    const IconCircle(icon: Icons.folder_outlined, size: 28),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        collection.updatedAt == null ? '최근 업데이트' : '${formatRelative(collection.updatedAt!)} 업데이트',
                        style: AppTypography.caption,
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
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

/// 1장(큰) + 2장(작은) 콜라주. 사진이 부족하면 플레이스홀더.
class CollectionCollage extends StatelessWidget {
  const CollectionCollage({super.key, required this.urls, this.height = 80});
  final List<String> urls;
  final double height;

  String? _at(int i) => i < urls.length ? urls[i] : null;

  @override
  Widget build(BuildContext context) {
    final small = (height - 4) / 2;
    return SizedBox(
      height: height,
      child: Row(
        children: [
          AppNetworkImage(url: _at(0), width: height * 0.85, height: height, radius: 12, placeholderIcon: Icons.folder_outlined),
          const SizedBox(width: 4),
          Column(
            children: [
              AppNetworkImage(url: _at(1), width: small, height: small, radius: 10),
              const SizedBox(height: 4),
              AppNetworkImage(url: _at(2), width: small, height: small, radius: 10),
            ],
          ),
        ],
      ),
    );
  }
}
