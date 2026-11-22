import 'package:flutter/material.dart';
import 'package:apt/core/widgets/spark_icon.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/selection.dart';
import '../../domain/course_models.dart';

/// 코스 장소 번호 원 — 선택 장소는 진한 번호, AI 추천은 주황 번호 + 작은 ✦ (번호는 끊기지 않고 색으로 구분)
class StopMarker extends StatelessWidget {
  const StopMarker({super.key, required this.source, this.number});
  final PlaceSource source;
  final int? number;

  static const double _size = 26; // v2 시안 .num 26

  @override
  Widget build(BuildContext context) {
    if (source == PlaceSource.ai) {
      return Semantics(
        label: number == null ? 'AI 추천' : '$number번, AI 추천',
        excludeSemantics: true,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            number == null
                ? Container(
                    width: _size,
                    height: _size,
                    decoration: const BoxDecoration(color: AppColors.ai, shape: BoxShape.circle),
                    child: const SparkIcon(size: _size * 0.5, color: Colors.white),
                  )
                : NumberBadge(number!, size: _size, color: AppColors.ai),
            if (number != null)
              // v2: 오른쪽 위에 작은 ✦ 글리프만 (흰 원 없이)
              const Positioned(right: -7, top: -7, child: SparkIcon(size: 12, color: AppColors.aiText)),
          ],
        ),
      );
    }
    return NumberBadge(number ?? 0, size: _size, color: AppColors.ink);
  }
}
