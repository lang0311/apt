import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

enum SegmentedStyle {
  /// 회색 트랙 위 흰 선택 칸 (저장됨)
  track,

  /// 분리된 pill, 선택=primary 채움 (코스 목록, 동행 설정)
  pills,
}

class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.style = SegmentedStyle.track,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final SegmentedStyle style;

  @override
  Widget build(BuildContext context) {
    return switch (style) {
      SegmentedStyle.track => _track(),
      SegmentedStyle.pills => _pills(),
    };
  }

  Widget _track() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selectedIndex ? AppColors.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: i == selectedIndex ? AppShadow.soft : null,
                  ),
                  child: Semantics(
                    selected: i == selectedIndex,
                    button: true,
                    child: Text(
                      labels[i],
                      style: AppTypography.label.copyWith(
                        color: i == selectedIndex ? AppColors.textPrimary : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pills() {
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Material(
              color: i == selectedIndex ? AppColors.primary : AppColors.surface,
              shape: StadiumBorder(
                side: BorderSide(color: i == selectedIndex ? AppColors.primary : AppColors.border),
              ),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => onChanged(i),
                child: SizedBox(
                  height: 40,
                  child: Center(
                    child: Text(
                      labels[i],
                      style: AppTypography.label.copyWith(
                        color: i == selectedIndex ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
