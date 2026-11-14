import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';

/// 직접 저장 · 추천받은 곳 칩 두 개. 바탕 없이 켜짐은 파랑 테두리 · 글자, 꺼짐은 회색. 둘 다 끌 수 있다 (07 D47)
class SourceChips extends StatelessWidget {
  const SourceChips({super.key, required this.showMine, required this.showAi, required this.onChanged});
  final bool showMine;
  final bool showAi;
  final void Function({bool? mine, bool? ai}) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SourceChip(label: '직접 저장', on: showMine, onTap: () => onChanged(mine: !showMine)),
        _SourceChip(label: '추천받은 곳', on: showAi, onTap: () => onChanged(ai: !showAi)),
      ],
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = on ? AppColors.primary : AppColors.textTertiary;
    return Semantics(
      button: true,
      toggled: on,
      label: '$label ${on ? '보는 중' : '숨김'}',
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        // 보이는 칩은 높이 26, 누르는 영역은 44
        child: SizedBox(
          height: 44,
          child: Center(
            child: Container(
              height: 26,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                shape: StadiumBorder(side: BorderSide(color: on ? AppColors.primary : AppColors.progressInactive, width: on ? 1.2 : 1)),
              ),
              child: Text(label, style: AppTypography.caption.copyWith(color: color, fontWeight: on ? FontWeight.w700 : FontWeight.w500)),
            ),
          ),
        ),
      ),
    );
  }
}
