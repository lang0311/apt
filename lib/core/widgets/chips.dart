import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// 선택형 칩 (32~34px 풀 라운드). 선택=primary 채움 / 비선택=흰+border
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.selectedColor = AppColors.primary,
    this.trailingCount,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color selectedColor;
  final int? trailingCount;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.textSecondary;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? selectedColor : AppColors.surface,
        shape: StadiumBorder(side: BorderSide(color: selected ? selectedColor : AppColors.border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: AppSpacing.chipHeight),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: AppTypography.label.copyWith(color: selected ? Colors.white : AppColors.textPrimary.withValues(alpha: 0.75))),
                if (trailingCount != null) ...[
                  const SizedBox(width: 6),
                  Text('$trailingCount', style: AppTypography.label.copyWith(color: fg)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 글자 칩: 투명 바탕 + 얇은 테두리, 고르면 글자만 primary · 굵게 (취향 설정, 07 D26).
/// 색만으로 구분하지 않도록 굵기도 바꾼다.
class AppTextChip extends StatelessWidget {
  const AppTextChip({super.key, required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  static const _line = Color(0xFFCFD7E3);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: Colors.transparent,
        shape: const StadiumBorder(side: BorderSide(color: _line)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: AppSpacing.chipHeight),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTypography.label.copyWith(
                    color: selected ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
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

/// 가로 스크롤 칩 행
class ChipScroller extends StatelessWidget {
  const ChipScroller({super.key, required this.children, this.padding = AppSpacing.screenPadding});
  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.xs),
            children[i],
          ],
        ],
      ),
    );
  }
}

enum AppTagTone { neutral, primary }

/// 읽기 전용 작은 태그 (키워드, "저장됨")
class AppTag extends StatelessWidget {
  const AppTag(this.label, {super.key, this.tone = AppTagTone.neutral});
  final String label;
  final AppTagTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      AppTagTone.neutral => (AppColors.surfaceMuted, AppColors.textSecondary),
      AppTagTone.primary => (AppColors.primarySoft, AppColors.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.pillAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppTypography.caption.copyWith(color: fg, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// 태그 묶음 (줄바꿈)
class TagWrap extends StatelessWidget {
  const TagWrap(this.labels, {super.key, this.tone = AppTagTone.neutral});
  final List<String> labels;
  final AppTagTone tone;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [for (final l in labels) AppTag(l, tone: tone)],
    );
  }
}
