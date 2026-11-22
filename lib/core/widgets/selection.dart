import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';

/// 체크 표시 (약관 동의, 목록·보관함·동행 선택): 배경·테두리 없이 체크 아이콘만, 고르면 primary (07 D26)
class CheckMark extends StatelessWidget {
  const CheckMark({super.key, required this.checked});
  final bool checked;

  static const _size = 22.0;

  // 안 고른 상태의 회색 체크
  static const _off = AppColors.checkOff;

  Color get _color => checked ? AppColors.primary : _off;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: TweenAnimationBuilder<Color?>(
        duration: const Duration(milliseconds: 150),
        tween: ColorTween(end: _color),
        builder: (_, color, _) => Icon(LucideIcons.check, size: _size, color: color, weight: 700),
      ),
    );
  }
}

/// 체크 원 (v2 시안 `.chk`): 24 원 + 흰 체크. 안 고르면 회색, 고르면 파랑. 행 오른쪽 하나로 고르기를 표시한다
class CheckCircle extends StatelessWidget {
  const CheckCircle({super.key, required this.checked});
  final bool checked;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 24,
      height: 24,
      decoration: BoxDecoration(color: checked ? AppColors.primary : AppColors.checkCircleOff, shape: BoxShape.circle),
      child: const Icon(LucideIcons.check, size: 15, color: Colors.white, weight: 700),
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
