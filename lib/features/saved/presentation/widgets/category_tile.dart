import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import 'category_style.dart';

/// 카테고리 타일 (아이콘 원 + 이름 + 개수). 선택 = 다크 배경.
class CategoryTile extends StatelessWidget {
  const CategoryTile({
    super.key,
    required this.label,
    required this.count,
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final CategoryStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.textPrimary;
    return Semantics(
      selected: selected,
      button: true,
      label: '$label $count곳',
      child: Material(
        color: selected ? AppColors.ink : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: selected ? Colors.white.withValues(alpha: 0.14) : style.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(style.icon, size: 16, color: selected ? Colors.white : style.color),
                ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(label, style: AppTypography.label.copyWith(color: selected ? Colors.white : AppColors.textSecondary)),
                    ),
                    Text('$count', style: AppTypography.section.copyWith(color: fg, fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
