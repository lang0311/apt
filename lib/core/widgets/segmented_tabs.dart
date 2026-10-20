import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

enum SegmentedStyle {
  /// 회색 트랙 위 흰 선택 칸 (저장됨)
  track,

  /// 분리된 pill, 선택=primary 채움 (코스 목록, 동행 설정)
  pills,

  /// 글자 + 밑줄, 선택=남색 굵은 글자 + 2px 밑줄 (저장됨, 2026-10-20)
  underline,
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
      SegmentedStyle.underline => _underline(),
    };
  }

  Widget _underline() {
    return DecoratedBox(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Semantics(
              selected: i == selectedIndex,
              button: true,
              child: InkWell(
                onTap: () => onChanged(i),
                child: Container(
                  height: 44,
                  margin: EdgeInsets.only(right: i == labels.length - 1 ? 0 : AppSpacing.lg),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: i == selectedIndex ? AppColors.ink : Colors.transparent, width: 2),
                    ),
                  ),
                  child: Text(
                    labels[i],
                    style: AppTypography.bodyStrong.copyWith(
                      color: i == selectedIndex ? AppColors.ink : AppColors.textSecondary,
                      fontWeight: i == selectedIndex ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
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
