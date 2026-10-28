import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/overlays.dart';
import '../../../place/domain/place.dart';
import '../../domain/saved_models.dart';
import 'category_style.dart';
import 'place_image.dart';

/// 저장 장소 한 행: 사진 56 · 이름 · '카테고리 · 동네' · ★평점/@출처(둘 다 없으면 셋째 줄 생략)
class SavedPlaceRow extends StatelessWidget {
  const SavedPlaceRow({super.key, required this.place, required this.onTap});
  final Place place;
  final VoidCallback onTap;

  /// '서울 성동구 성수동' → '성수동'
  static String shortArea(Place p) => p.displayArea.trim().split(RegExp(r'\s+')).last;

  /// 출처 계정을 '@계정' 꼴로. 없으면 null.
  static String? _handleOf(Place place) {
    final handle = place.sourceHandle;
    if (handle == null || handle.isEmpty) return null;
    return handle.startsWith('@') ? handle : '@$handle';
  }

  @override
  Widget build(BuildContext context) {
    final area = shortArea(place);
    final handle = _handleOf(place);
    final hasThird = place.rating != null || handle != null;

    return Semantics(
      button: true,
      label: [place.name, place.categoryLabel, area, if (place.rating != null) '평점 ${place.rating}'].join(', '),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 76),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
            child: Row(
              children: [
                PlaceImage(place: place, width: 56, height: 56),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(place.name, style: AppTypography.bodyStrong.copyWith(fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        [place.categoryLabel, if (area.isNotEmpty) area].join(' · '),
                        style: AppTypography.meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (hasThird) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (place.rating != null) ...[
                              const Icon(Icons.star_rounded, size: 13, color: Color(0xFFF5A524)),
                              const SizedBox(width: 2),
                              Text(place.rating!.toStringAsFixed(1), style: AppTypography.caption.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                              const SizedBox(width: AppSpacing.xs),
                            ],
                            if (handle != null)
                              Flexible(child: Text(handle, style: AppTypography.caption, maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 보관함 한 행: 2×2 미니 콜라주 · 이름 · 'n곳 · 방금 수정' · ⋯
class CollectionRow extends StatelessWidget {
  const CollectionRow({super.key, required this.collection, required this.onTap, required this.onMore});
  final PlaceCollection collection;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final meta = [
      '${collection.placeCount}곳',
      if (collection.updatedAt != null) '${formatRecentDate(collection.updatedAt!)} 수정',
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 76),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 10, AppSpacing.xxs, 10),
          child: Row(
            children: [
              MiniCollage(urls: collection.thumbnailUrls),
              const SizedBox(width: 14),
              Expanded(
                child: Semantics(
                  button: true,
                  label: '${collection.name}, $meta',
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        collection.name,
                        style: AppTypography.bodyStrong.copyWith(fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(meta, style: AppTypography.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: onMore,
                tooltip: '${collection.name} 메뉴',
                icon: const Icon(Icons.more_horiz_rounded, color: AppColors.textSecondary),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 썸네일 최대 4장, 모자라면 회색 칸, 0장이면 폴더 아이콘
class MiniCollage extends StatelessWidget {
  const MiniCollage({super.key, required this.urls, this.size = 56});
  final List<String> urls;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(AppRadius.thumb)),
        child: const Icon(Icons.folder_outlined, color: AppColors.textSecondary),
      );
    }
    final cell = (size - 1.5) / 2;
    Widget tile(int index) {
      if (index < urls.length) return AppNetworkImage(url: urls[index], width: cell, height: cell, radius: 0);
      return Container(width: cell, height: cell, color: AppColors.surfaceMuted);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.thumb),
      child: SizedBox(
        width: size,
        height: size,
        child: Column(
          children: [
            Row(children: [tile(0), const SizedBox(width: 1.5), tile(1)]),
            const SizedBox(height: 1.5),
            Row(children: [tile(2), const SizedBox(width: 1.5), tile(3)]),
          ],
        ),
      ),
    );
  }
}

/// 보관함 탭의 '저장한 장소 전체 n곳 · 보기 ›' 안내 줄 (07 D21 ②)
class AllPlacesLink extends StatelessWidget {
  const AllPlacesLink({super.key, required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xxs),
      child: Material(
        color: AppColors.surfaceRaised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm), side: const BorderSide(color: AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(7)),
                    child: const Icon(Icons.bookmark_border_rounded, size: 15, color: AppColors.primary),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text('저장한 장소 전체 $count곳', style: AppTypography.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Text('보기', style: AppTypography.caption),
                  const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 제목 줄 오른쪽 글자 버튼 ('필터', '+ 새 보관함'). [active]면 파란 글자 + 연파랑 바탕.
class HeaderTextButton extends StatelessWidget {
  const HeaderTextButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.active = false,
    this.primary = false,
    this.semanticLabel,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool active;

  /// 파란 글자(바탕 없음). '+ 새 보관함'에 쓴다.
  final bool primary;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final fg = active || primary ? AppColors.primary : AppColors.textPrimary;
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: Material(
        color: active ? AppColors.primarySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 17, color: fg),
                  const SizedBox(width: 4),
                  Text(label, style: AppTypography.label.copyWith(color: fg)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 걸린 카테고리 칩 (남색, ×로 해제)
class AppliedFilterChip extends StatelessWidget {
  const AppliedFilterChip({super.key, required this.label, required this.onClear});
  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label 필터 해제',
      excludeSemantics: true,
      child: Material(
        color: AppColors.ink,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onClear,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 7, AppSpacing.xs, 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: AppTypography.label.copyWith(color: Colors.white, fontSize: 12.5)),
                const SizedBox(width: 2),
                const Icon(Icons.close_rounded, size: 15, color: Colors.white70),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 카테고리 시트: 전체 + 서버 대분류(아이콘·개수). 하나를 누르면 바로 닫히며 [onSelected]를 부른다. 0곳은 누를 수 없다.
/// '전체'는 null로 선택, 그냥 닫으면 아무 일도 없다.
Future<void> showCategoryFilterSheet(
  BuildContext context, {
  required SavedSummary summary,
  required String? selectedKey,
  required ValueChanged<String?> onSelected,
}) {
  void select(BuildContext ctx, String? key) {
    Navigator.of(ctx).pop();
    onSelected(key);
  }

  return showAppBottomSheet<void>(
    context,
    builder: (ctx) => SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xxs, AppSpacing.lg, AppSpacing.xs),
            child: Text('카테고리', style: AppTypography.section),
          ),
          _CategoryOption(
            label: '전체',
            count: summary.totalCount,
            style: const CategoryStyle(Icons.format_list_bulleted_rounded, AppColors.primary),
            selected: selectedKey == null,
            onTap: () => select(ctx, null),
          ),
          for (final category in summary.categories)
            _CategoryOption(
              label: category.label,
              count: category.count,
              style: CategoryStyle.of(category.key),
              selected: selectedKey == category.key,
              onTap: category.count == 0 ? null : () => select(ctx, category.key),
            ),
        ],
      ),
    ),
  );
}

class _CategoryOption extends StatelessWidget {
  const _CategoryOption({required this.label, required this.count, required this.style, required this.selected, required this.onTap});
  final String label;
  final int count;
  final CategoryStyle style;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: '$label $count곳',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: style.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
                    child: Icon(style.icon, size: 19, color: style.color),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    label,
                    style: AppTypography.bodyStrong.copyWith(
                      color: selected ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('$count', style: AppTypography.meta),
                  const Spacer(),
                  if (selected) const Icon(Icons.check_rounded, color: AppColors.primary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
