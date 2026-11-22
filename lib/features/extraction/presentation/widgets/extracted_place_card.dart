import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/selection.dart';
import '../../../saved/presentation/widgets/place_image.dart';
import '../../../saved/presentation/widgets/saved_rows.dart';
import '../../domain/extraction_models.dart';

/// 추출 화면 맨 위 링크 줄. 링크 입력 · 찾는 중 · 찾은 장소 · 실패에서 같은 자리 · 같은 모양이라
/// 화면이 바뀌어도 아래 카드만 바뀐다 (07 D26).
class ExtractSourceRow extends StatelessWidget {
  const ExtractSourceRow({super.key, required this.leading, required this.child, this.action, this.focused = false});

  final Widget leading;
  final Widget child;
  final Widget? action;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 6, AppSpacing.xxs, 6),
      // v2: 채움 바탕 · 테두리 없음, 입력 중에만 흰 바탕 + 파란 2px
      decoration: BoxDecoration(
        color: focused ? AppColors.surface : AppColors.fill,
        borderRadius: AppRadius.inputAll,
        border: Border.all(color: focused ? AppColors.primary : Colors.transparent, width: 2),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: child),
          if (action != null) action! else const SizedBox(width: AppSpacing.sm),
        ],
      ),
    );
  }
}

/// 링크 줄 왼쪽 칸: 링크 아이콘 (지도 검색 줄은 돋보기)
class LinkTile extends StatelessWidget {
  const LinkTile({super.key, this.icon = LucideIcons.link});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 24, height: 30, child: Icon(icon, size: 20, color: AppColors.textSecondary));
  }
}

/// 링크 줄 왼쪽 칸: 인스타그램 게시물 (계정 이름을 받았을 때). v2: 잉크 선 글리프(둥근 네모 + 원 + 점)
class InstagramTile extends StatelessWidget {
  const InstagramTile({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 30,
      child: Center(
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.textPrimary, width: 1.8),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.textPrimary, width: 1.8),
                ),
              ),
              Positioned(
                right: 2.5,
                top: 2.5,
                child: Container(
                  width: 2.4,
                  height: 2.4,
                  decoration: const BoxDecoration(color: AppColors.textPrimary, shape: BoxShape.circle),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 링크 줄 오른쪽 글자 버튼 ('찾기', '게시물 보기')
class SourceRowAction extends StatelessWidget {
  const SourceRowAction({super.key, required this.label, this.onPressed, this.external = false});
  final String label;
  final VoidCallback? onPressed;

  /// 앱 밖으로 나가는 버튼: 회색 글자 + ↗ (v2 '게시물 보기 ↗')
  final bool external;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        // 비활성은 파랑을 흐리게 하지 않고 회색으로 (흐린 파랑은 흰 바탕에서 거의 안 읽힌다)
        disabledForegroundColor: AppColors.textTertiary,
        minimumSize: const Size(48, 44),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      ),
      child: external
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTypography.label.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 3),
                const Icon(LucideIcons.arrowUpRight, size: 14, color: AppColors.textSecondary),
              ],
            )
          : Text(
              label,
              style: AppTypography.label.copyWith(color: onPressed == null ? AppColors.textTertiary : AppColors.primary, fontWeight: FontWeight.w600),
            ),
    );
  }
}

/// 찾은 장소 한 행: 사진 56 · 이름 · '카테고리 · 동네' · 넣을 보관함 · [보관함] · 체크.
/// 이미 저장한 장소는 흐리게 '저장됨'.
class ExtractedPlaceRow extends StatelessWidget {
  const ExtractedPlaceRow({
    super.key,
    required this.item,
    required this.selected,
    required this.collectionLabel,
    required this.onToggle,
    required this.onPickCollection,
  });

  final ExtractedPlace item;
  final bool selected;

  /// 고른 보관함 이름 ('성수동 데이트', '성수동 데이트 외 1'). 없으면 null.
  final String? collectionLabel;
  final VoidCallback onToggle;
  final VoidCallback onPickCollection;

  @override
  Widget build(BuildContext context) {
    final place = item.place;
    final saved = item.alreadySaved;
    final area = SavedPlaceRow.shortArea(place);
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 10, AppSpacing.xs, 10),
      child: Row(
        children: [
          PlaceImage(place: place, width: 56, height: 56, radius: 14),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  style: AppTypography.bodyStrong.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text([place.categoryLabel, if (area.isNotEmpty) area].join(' · '), style: AppTypography.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
                // v2: 보관함은 이름 아래 파란 글자 한 줄 (고른 게 없으면 '보관함 고르기 ›', 고르면 '○○에 담아요')
                if (!saved)
                  Semantics(
                    button: true,
                    label: '${place.name} 보관함 고르기',
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: onPickCollection,
                      borderRadius: BorderRadius.circular(AppRadius.small),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 28),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          widthFactor: 1,
                          child: Text(
                            collectionLabel == null ? '보관함 고르기 ›' : '$collectionLabel에 담아요',
                            // v2: 고르기 전은 회색, 고른 뒤 '○○에 담아요'는 파랑
                            style: collectionLabel == null
                                ? AppTypography.meta.copyWith(color: AppColors.textSecondary)
                                : AppTypography.meta.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          if (saved)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Text('저장됨', style: AppTypography.meta),
            )
          else ...[
            Semantics(
              selected: selected,
              label: '${place.name} 저장',
              button: true,
              child: InkResponse(
                onTap: onToggle,
                radius: 22,
                child: SizedBox(
                  width: 40,
                  height: 44,
                  child: Center(child: CheckCircle(checked: selected)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
    if (saved) return Opacity(opacity: 0.6, child: row);
    return InkWell(onTap: onToggle, child: row);
  }
}
