import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/surfaces.dart';
import '../recommendation_controller.dart';

/// 다시 추천하는 동안 일정 위에 두는 한 줄(작은 진행 원 + 문구 + 취소). 이전 결과는 아래에 그대로 둔다.
/// 카드 안에 칸을 또 띄우지 않으려고 바탕 없이 글자 줄로만 둔다(07 D57 · D60).
class RecommendingBanner extends StatelessWidget {
  /// 지금 상태에 맞는 줄 — 다시 추천은 AI 자리 수, 한 곳 바꾸기는 다른 문구
  RecommendingBanner.of(RecommendationState state, {super.key, required this.onCancel})
    : count = state.loadingIds.length,
      kind = state.reroll;

  final VoidCallback onCancel;

  /// 다시 고르는 AI 자리 수 (0이면 수를 빼고 말한다)
  final int count;

  /// 한 곳 바꾸기는 다른 문구, 몇 곳이 바뀔지 모르는 바꾸기는 수를 뺀다
  final RerollKind kind;

  @override
  Widget build(BuildContext context) {
    final text = switch (kind) {
      RerollKind.one => '다른 장소를 찾고 있어요',
      RerollKind.all when count > 0 => 'AI 장소 $count곳을 다시 고르고 있어요',
      _ => 'AI 장소를 다시 고르고 있어요',
    };
    return Padding(
      padding: const EdgeInsets.only(left: SectionCard.innerPadding, right: 4),
      child: Row(
        children: [
          const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(text, style: AppTypography.label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(foregroundColor: AppColors.primary, minimumSize: const Size(48, 44)),
            child: Text('취소', style: AppTypography.label.copyWith(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}
