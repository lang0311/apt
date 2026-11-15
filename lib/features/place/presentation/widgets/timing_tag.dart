import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/place_timing.dart';

/// 일정 줄 카테고리 앞의 작은 태그: "팝업 · 11/29까지", 빨강 "팝업 · 11/22 종료", 초록 "신규 오픈".
/// 주황은 AI 추천 표시 전용이라 쓰지 않는다(07 D17).
class TimingTag extends StatelessWidget {
  const TimingTag(this.badge, {super.key});
  final TimingBadge badge;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (badge.tone) {
      TimingTone.normal => (AppColors.surfaceMuted, AppColors.ink),
      TimingTone.fresh => (AppColors.successSoft, AppColors.categoryCultureInk),
      TimingTone.warn => (AppColors.dangerSoft, AppColors.dangerText),
      TimingTone.ended => (AppColors.surfaceMuted, AppColors.disabledText),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.small)),
      child: Text(
        badge.text,
        maxLines: 1,
        style: AppTypography.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          decoration: badge.tone == TimingTone.ended ? TextDecoration.lineThrough : null,
          decorationColor: fg,
        ),
      ),
    );
  }
}
