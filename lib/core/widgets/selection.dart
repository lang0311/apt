import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';

/// 체크 표시: 배경·테두리 없이 체크 아이콘만, 고르면 primary (07 D26)
class _CheckMark extends StatelessWidget {
  const _CheckMark({required this.checked, required this.size});
  final bool checked;
  final double size;

  // 안 고른 상태의 회색 체크
  static const _off = Color(0xFFC3CBD7);

  Color get _color => checked ? AppColors.primary : _off;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<Color?>(
        duration: const Duration(milliseconds: 150),
        tween: ColorTween(end: _color),
        builder: (_, color, _) => Icon(Icons.check_rounded, size: size, color: color, weight: 700),
      ),
    );
  }
}

/// 체크 (약관 동의, 목록 선택)
class CircleCheck extends StatelessWidget {
  const CircleCheck({super.key, required this.checked});
  final bool checked;

  @override
  Widget build(BuildContext context) => _CheckMark(checked: checked, size: 22);
}

/// 체크 (보관함 선택, 장소 추가). 모양은 [CircleCheck]와 같다.
class SquareCheck extends StatelessWidget {
  const SquareCheck({super.key, required this.checked, this.size = 22});
  final bool checked;
  final double size;

  @override
  Widget build(BuildContext context) => _CheckMark(checked: checked, size: size);
}

/// 선택 체크
class RadioDot extends StatelessWidget {
  const RadioDot({super.key, required this.selected, this.size = 22});
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) => _CheckMark(checked: selected, size: size);
}

/// 번호 원 (선택 순서, 코스 순번)
class NumberBadge extends StatelessWidget {
  const NumberBadge(this.number, {super.key, this.size = 24, this.color = AppColors.primary, this.textColor = Colors.white});
  final int number;
  final double size;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        '$number',
        style: AppTypography.caption.copyWith(color: textColor, fontWeight: FontWeight.w700, fontSize: size * 0.46),
      ),
    );
  }
}
