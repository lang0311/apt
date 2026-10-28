import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/selection.dart';
import '../../domain/course_models.dart';

/// 코스 장소 번호 원 — 선택 장소는 파랑 번호, AI 추천은 주황 ✦ (항상 구분)
class StopMarker extends StatelessWidget {
  const StopMarker({super.key, required this.source, this.number, this.size = 28, this.dark = false});
  final PlaceSource source;
  final int? number;
  final double size;

  /// 코스 상세 일정의 진한 번호 원
  final bool dark;

  @override
  Widget build(BuildContext context) {
    if (source == PlaceSource.ai) {
      return Semantics(
        label: 'AI 추천',
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: dark ? AppColors.aiSoft : AppColors.ai, shape: BoxShape.circle),
          child: Icon(Icons.auto_awesome, size: size * 0.5, color: dark ? AppColors.ai : Colors.white),
        ),
      );
    }
    return NumberBadge(number ?? 0, size: size, color: dark ? AppColors.ink : AppColors.primary);
  }
}
