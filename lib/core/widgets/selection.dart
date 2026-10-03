import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';

/// 원형 체크 (약관 동의)
class CircleCheck extends StatelessWidget {
  const CircleCheck({super.key, required this.checked, this.size = 22});
  final bool checked;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: checked ? AppColors.primary : AppColors.surface,
        border: Border.all(color: checked ? AppColors.primary : AppColors.border, width: 1.4),
      ),
      child: Icon(Icons.check_rounded, size: size * 0.7, color: checked ? Colors.white : AppColors.textHint),
    );
  }
}

/// 사각 체크박스 (보관함 선택, 장소 추가)
class SquareCheck extends StatelessWidget {
  const SquareCheck({super.key, required this.checked, this.size = 22});
  final bool checked;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        color: checked ? AppColors.primary : AppColors.surface,
        border: Border.all(color: checked ? AppColors.primary : AppColors.border, width: 1.4),
      ),
      child: checked ? Icon(Icons.check_rounded, size: size * 0.75, color: Colors.white) : null,
    );
  }
}

/// 라디오 점 (추출 결과 선택)
class RadioDot extends StatelessWidget {
  const RadioDot({super.key, required this.selected, this.enabled = true, this.size = 22});
  final bool selected;
  final bool enabled;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.primary : (enabled ? AppColors.surface : AppColors.surfaceMuted),
        border: Border.all(color: selected ? AppColors.primary : AppColors.textHint, width: 1.4),
      ),
      child: selected ? Icon(Icons.check_rounded, size: size * 0.7, color: Colors.white) : null,
    );
  }
}

/// 번호 원 (선택 순서, 코스 순번)
class NumberBadge extends StatelessWidget {
  const NumberBadge(this.number, {super.key, this.size = 24, this.color = AppColors.primary});
  final int number;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        '$number',
        style: AppTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * 0.46),
      ),
    );
  }
}
