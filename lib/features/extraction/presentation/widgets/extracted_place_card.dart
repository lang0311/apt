import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/chips.dart';
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
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: focused ? AppColors.primary : AppColors.border, width: focused ? 1.5 : 1),
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
  const LinkTile({super.key, this.icon = Icons.link_rounded});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(9)),
      child: Icon(icon, size: 18, color: AppColors.textSecondary),
    );
  }
}

/// 링크 줄 왼쪽 칸: 인스타그램 게시물 (계정 이름을 받았을 때)
class InstagramTile extends StatelessWidget {
  const InstagramTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF58529), Color(0xFFDD2A7B), Color(0xFF8134AF)],
        ),
      ),
    );
  }
}

/// 링크 줄 오른쪽 글자 버튼 ('찾기', '게시물 보기')
class SourceRowAction extends StatelessWidget {
  const SourceRowAction({super.key, required this.label, this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        disabledForegroundColor: AppColors.primary.withValues(alpha: 0.35),
        minimumSize: const Size(48, 44),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      ),
      child: Text(
        label,
        style: AppTypography.label.copyWith(color: onPressed == null ? AppColors.primary.withValues(alpha: 0.35) : AppColors.primary),
      ),
    );
  }
}

/// 찾은 장소 한 행: 사진 48 · 이름 · '카테고리 · 동네' · 넣을 보관함 · [보관함] · 체크.
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
          PlaceImage(place: place, width: 48, height: 48, radius: 12),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(place.name, style: AppTypography.bodyStrong.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text([place.categoryLabel, if (area.isNotEmpty) area].join(' · '), style: AppTypography.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (collectionLabel != null && !saved) ...[
                  const SizedBox(height: 2),
                  Text(collectionLabel!, style: AppTypography.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          if (saved)
            const Padding(padding: EdgeInsets.only(right: AppSpacing.xs), child: AppTag('저장됨'))
          else ...[
            _CollectionButton(active: collectionLabel != null, onTap: onPickCollection, placeName: place.name),
            Semantics(
              selected: selected,
              label: '${place.name} 저장',
              button: true,
              child: InkResponse(
                onTap: onToggle,
                radius: 22,
                child: SizedBox(width: 40, height: 44, child: Center(child: CheckMark(checked: selected))),
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

/// '보관함' 글자 버튼: 투명 바탕 + 얇은 테두리, 고르면 파란 테두리 · 글자 (07 D26)
class _CollectionButton extends StatelessWidget {
  const _CollectionButton({required this.active, required this.onTap, required this.placeName});
  final bool active;
  final VoidCallback onTap;
  final String placeName;

  static const _line = Color(0xFFCFD7E3);
  static const _activeLine = Color(0xFF9FBDFD);

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.xs),
      side: BorderSide(color: active ? _activeLine : _line),
    );
    return Semantics(
      button: true,
      label: '$placeName 보관함 고르기',
      excludeSemantics: true,
      // 보이는 버튼은 30 높이, 누르는 영역은 44
      child: SizedBox(
        height: 44,
        child: Center(
          child: Material(
            color: Colors.transparent,
            shape: shape,
            child: InkWell(
              customBorder: shape,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  '보관함',
                  style: AppTypography.meta.copyWith(
                    color: active ? AppColors.primary : AppColors.textPrimary,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
