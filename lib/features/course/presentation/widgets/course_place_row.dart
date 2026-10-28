import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/selection.dart';
import '../../domain/course_models.dart';

/// 코스 장소 번호 원 — 선택 장소는 진한 번호, AI 추천은 주황 ✦ (항상 구분)
class StopMarker extends StatelessWidget {
  const StopMarker({super.key, required this.source, this.number});
  final PlaceSource source;
  final int? number;

  static const double _size = 26;

  @override
  Widget build(BuildContext context) {
    if (source == PlaceSource.ai) {
      return Semantics(
        label: 'AI 추천',
        child: Container(
          width: _size,
          height: _size,
          decoration: const BoxDecoration(color: AppColors.ai, shape: BoxShape.circle),
          child: const Icon(Icons.auto_awesome, size: _size * 0.5, color: Colors.white),
        ),
      );
    }
    return NumberBadge(number ?? 0, size: _size, color: AppColors.ink);
  }
}
