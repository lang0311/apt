import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/overlays.dart';
import '../../domain/course_models.dart';

/// 장소 시트의 한 줄
class StopSheetAction {
  const StopSheetAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.description,
    this.onceScope = false,
    this.danger = false,
    this.chevron = false,
  });

  final String label;
  final String? description;
  final IconData icon;
  final VoidCallback onTap;

  /// "이번만" 표시 (이 코스에서만 빼는 동작)
  final bool onceScope;

  /// 차단처럼 되돌리기 어려운 동작 — 빨간 글자, 따로 떼어 둔다
  final bool danger;
  final bool chevron;
}

/// 장소 머리(사진 · 이름 · 부제 · AI 이유) + 묶음별 동작. 묶음 사이는 바탕색 띠로 나눈다.
Future<void> showStopSheet(BuildContext context, {required CourseStop stop, required List<List<StopSheetAction>> groups}) {
  final place = stop.place;
  return showAppBottomSheet<void>(
    context,
    builder: (ctx) => SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xxs, AppSpacing.screenH, AppSpacing.sm),
            child: Row(
              children: [
                AppNetworkImage(url: place.imageUrl, width: 44, height: 44, radius: 12),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(place.name, style: AppTypography.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        [place.categoryLabel, if (place.displayArea.isNotEmpty) place.displayArea, if (!stop.isAi) '내가 고른 장소'].join(' · '),
                        style: AppTypography.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (stop.isAi && stop.aiReason != null)
                        Text('✦ ${stop.aiReason}', style: AppTypography.caption.copyWith(color: AppColors.aiText, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (var g = 0; g < groups.length; g++) ...[
            if (g > 0) Container(height: 6, color: AppColors.bg, margin: const EdgeInsets.symmetric(vertical: 4)),
            for (final a in groups[g]) _ActionRow(action: a, sheetContext: ctx),
          ],
        ],
      ),
    ),
  );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.action, required this.sheetContext});
  final StopSheetAction action;
  final BuildContext sheetContext;

  @override
  Widget build(BuildContext context) {
    final a = action;
    final (bg, fg) = a.danger
        ? (AppColors.dangerSoft, AppColors.dangerText)
        : a.icon == Icons.swap_horiz_rounded
            ? (AppColors.aiSoft, AppColors.aiText)
            : a.chevron
                ? (AppColors.primarySoft, AppColors.primary)
                : (AppColors.surfaceMuted, AppColors.textPrimary);
    return InkWell(
      onTap: () {
        Navigator.of(sheetContext).pop();
        a.onTap();
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                child: Icon(a.icon, size: 20, color: fg),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            a.label,
                            style: AppTypography.bodyStrong.copyWith(color: a.danger ? AppColors.dangerText : null),
                          ),
                        ),
                        if (a.onceScope) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(5)),
                            child: Text('이번만', style: AppTypography.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ],
                    ),
                    if (a.description != null) Text(a.description!, style: AppTypography.caption),
                  ],
                ),
              ),
              if (a.chevron) const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}

/// 4단계 결과에서 장소를 누를 때.
/// AI 장소: 바꾸기 · 이 코스에서 빼기(이번만) / 앞으로 추천하지 않기(차단) / 장소 정보.
/// 내가 고른 장소: 장소 정보 · 이 코스에서 빼기 (차단 없음, 저장됨에는 그대로).
Future<void> showResultStopSheet(
  BuildContext context, {
  required CourseStop stop,
  required VoidCallback onInfo,
  required VoidCallback onRemove,
  VoidCallback? onSwap,
  VoidCallback? onBlock,
}) {
  final info = StopSheetAction(label: '장소 정보 보기', icon: Icons.place_outlined, onTap: onInfo, chevron: true);
  if (!stop.isAi) {
    return showStopSheet(context, stop: stop, groups: [
      [info, _removeOwn(onRemove)],
    ]);
  }
  return showStopSheet(context, stop: stop, groups: [
    [
      if (onSwap != null)
        StopSheetAction(
          label: '다른 곳으로 바꾸기',
          description: '이 자리에 다른 장소를 추천해요',
          icon: Icons.swap_horiz_rounded,
          onceScope: true,
          onTap: onSwap,
        ),
      _removeAi(onRemove),
    ],
    if (onBlock != null) [_block(onBlock)],
    [info],
  ]);
}

/// 편집 화면에서 장소 타일을 누를 때: 앞으로 · 뒤로 · 이 코스에서 빼기 / (AI 장소만) 앞으로 추천하지 않기
Future<void> showEditStopSheet(
  BuildContext context, {
  required CourseStop stop,
  VoidCallback? onUp,
  VoidCallback? onDown,
  required VoidCallback onRemove,
  VoidCallback? onBlock,
}) {
  return showStopSheet(context, stop: stop, groups: [
    [
      if (onUp != null) StopSheetAction(label: '앞으로', icon: Icons.arrow_upward_rounded, onTap: onUp),
      if (onDown != null) StopSheetAction(label: '뒤로', icon: Icons.arrow_downward_rounded, onTap: onDown),
      if (stop.isAi) _removeAi(onRemove) else _removeOwn(onRemove),
    ],
    if (stop.isAi && onBlock != null) [_block(onBlock)],
  ]);
}

StopSheetAction _removeAi(VoidCallback onTap) => StopSheetAction(
      label: '이 코스에서 빼기',
      description: '자리는 비우고 시간만 다시 계산해요',
      icon: Icons.remove_rounded,
      onceScope: true,
      onTap: onTap,
    );

StopSheetAction _removeOwn(VoidCallback onTap) => StopSheetAction(
      label: '이 코스에서 빼기',
      description: '저장한 장소는 그대로 있어요',
      icon: Icons.remove_rounded,
      onTap: onTap,
    );

StopSheetAction _block(VoidCallback onTap) => StopSheetAction(
      label: '앞으로 추천하지 않기',
      description: '모든 코스 추천에서 이 장소를 빼요',
      icon: Icons.block_rounded,
      danger: true,
      onTap: onTap,
    );
