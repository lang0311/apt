import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/surfaces.dart';

/// 다시 추천하는 동안 일정 카드 맨 위에 두는 줄 (+ 취소). 이전 결과는 아래에 그대로 둔다.
class RecommendingBanner extends StatelessWidget {
  const RecommendingBanner({super.key, required this.onCancel});
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(SectionCard.innerPadding, 0, SectionCard.innerPadding, AppSpacing.xs),
      child: Container(
        padding: const EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.xxs),
        decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text('AI 장소를 다시 고르고 있어요', style: AppTypography.bodyStrong),
              ),
            ),
            TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(foregroundColor: AppColors.primary, minimumSize: const Size(48, 44)),
              child: Text('취소', style: AppTypography.bodyStrong.copyWith(color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
  }
}
