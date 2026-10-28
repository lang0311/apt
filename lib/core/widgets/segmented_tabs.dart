import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// 밑줄 탭: 선택=남색 굵은 글자 + 2px 밑줄 (저장됨, 코스 목록)
class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.counts,
  });

  final List<String> labels;

  /// 탭 이름 옆 개수 (서버 목록 길이). null이면 표시하지 않는다.
  final List<int?>? counts;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
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
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: labels[i]),
                      if (counts?[i] != null)
                        TextSpan(
                          text: ' ${counts![i]}',
                          style: const TextStyle(color: AppColors.textTertiary, fontWeight: FontWeight.w600),
                        ),
                    ]),
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
}
