import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// 순서가 있는 안내를 노선 정거장처럼 (리디자인 v2): 파란 번호 원을 세로 선으로 잇고 오른쪽에 제목 · 설명.
/// 가입 완료 · 홈 처음 상태 · 장소 추가 안내에서 같은 모양으로 쓴다.
class StationSteps extends StatelessWidget {
  const StationSteps({super.key, required this.steps, this.gap = 18});

  /// (제목, 설명 또는 null)
  final List<(String, String?)> steps;

  /// 정거장 사이 간격
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 26,
                  child: Column(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        child: Text('${i + 1}', style: AppTypography.label.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                      if (i < steps.length - 1) Expanded(child: Container(width: 2, color: AppColors.divider)),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 2, bottom: i < steps.length - 1 ? gap : 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(steps[i].$1, style: AppTypography.bodyStrong.copyWith(fontSize: 16)),
                        if (steps[i].$2 != null) ...[
                          const SizedBox(height: 2),
                          Text(steps[i].$2!, style: AppTypography.meta),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
