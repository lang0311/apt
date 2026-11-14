import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/overlays.dart';
import '../../../saved/presentation/widgets/place_image.dart';
import '../../domain/course_models.dart';

/// 장소 시트 한 줄의 색 구분
enum StopSheetTone {
  normal,

  /// AI 추천 동작(바꾸기). 아이콘 색은 보통 줄과 같다 — 주황은 '추천 이유 보기'에만(07 D17 · D60)
  ai,

  /// 다른 화면으로 가는 동작 (오른쪽 ›)
  link,

  /// 차단처럼 되돌리기 어려운 동작 — 빨간 아이콘·글자, 따로 떼어 둔다
  danger,
}

/// 장소 시트의 한 줄
class StopSheetAction {
  const StopSheetAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.description,
    this.onceScope = false,
    this.tone = StopSheetTone.normal,
    this.chevron = false,
  });

  final String label;
  final String? description;
  final IconData icon;
  final VoidCallback onTap;

  /// "이번만" 표시 (이 코스에서만 빼는 동작)
  final bool onceScope;
  final StopSheetTone tone;
  final bool chevron;
}

/// 장소 머리(사진 또는 카테고리 색 칸 · 이름 · 부제) + 묶음별 동작. 묶음 사이는 바탕색 띠로 나눈다.
/// 줄 아이콘은 색 칸 없이 선 아이콘만 둔다(07 D60). AI 장소의 '추천 이유 보기'는 첫 묶음의
/// [reasonAfter]번째 줄 뒤에 둔다(0이면 맨 위 — 4단계 결과는 '다른 곳으로 바꾸기' 다음).
Future<void> showStopSheet(
  BuildContext context, {
  required CourseStop stop,
  required List<List<StopSheetAction>> groups,
  int reasonAfter = 0,
}) {
  final place = stop.place;
  final reason = stop.isAi && stop.aiReason != null ? _ReasonRow(reason: stop.aiReason!) : null;
  const line = Divider(height: 1, indent: AppSpacing.screenH, endIndent: AppSpacing.screenH, color: AppColors.divider);
  List<Widget> rows(BuildContext ctx, int g) {
    final items = <Widget>[
      for (final a in groups[g]) _ActionRow(action: a, sheetContext: ctx),
    ];
    if (g == 0 && reason != null) items.insert(reasonAfter.clamp(0, items.length), reason);
    return [
      for (final (i, w) in items.indexed) ...[if (i > 0) line, w],
    ];
  }

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
                // 저장됨 · 장소 고르기와 같은 썸네일 (사진이 없으면 카테고리 색 칸)
                PlaceImage(place: place, width: 44, height: 44, radius: AppRadius.small, iconSize: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(place.name, style: AppTypography.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        [place.categoryLabel, if (place.shortArea.isNotEmpty) place.shortArea, if (!stop.isAi) '내가 고른 장소'].join(' · '),
                        style: AppTypography.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (var g = 0; g < groups.length; g++) ...[
            if (g > 0) Container(height: 6, color: AppColors.bg, margin: const EdgeInsets.symmetric(vertical: 4)),
            ...rows(ctx, g),
          ],
        ],
      ),
    ),
  );
}

/// '추천 이유 보기': 누르면 시트를 닫지 않고 아래에 이유를 펼친다 (07 D40).
/// 서버가 주는 이유가 길어서 일정에서는 빼고 여기서만 보여 준다.
class _ReasonRow extends StatefulWidget {
  const _ReasonRow({required this.reason});
  final String reason;

  @override
  State<_ReasonRow> createState() => _ReasonRowState();
}

class _ReasonRowState extends State<_ReasonRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          expanded: _open,
          child: InkWell(
            onTap: () => setState(() => _open = !_open),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: 8),
                child: Row(
                  children: [
                    const SizedBox(width: 28, child: Icon(Icons.auto_awesome, size: 20, color: AppColors.ai)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text('추천 이유 보기', style: AppTypography.bodyStrong.copyWith(color: AppColors.aiText))),
                    Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_open)
          Padding(
            // 아이콘(28) + 간격만큼 들여 써서 줄 제목 아래에 맞춘다
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenH + 28 + AppSpacing.sm, 0, AppSpacing.screenH, AppSpacing.sm),
            child: Text(widget.reason, style: AppTypography.body.copyWith(color: AppColors.textPrimary, height: 1.55)),
          ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.action, required this.sheetContext});
  final StopSheetAction action;
  final BuildContext sheetContext;

  @override
  Widget build(BuildContext context) {
    // 색 칸 없이 선 아이콘만. 지우기 · 차단만 빨강
    final fg = action.tone == StopSheetTone.danger ? AppColors.dangerText : AppColors.textPrimary;
    return InkWell(
      onTap: () {
        Navigator.of(sheetContext).pop();
        action.onTap();
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: 8),
          child: Row(
            children: [
              SizedBox(width: 28, child: Icon(action.icon, size: 22, color: fg)),
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
                            action.label,
                            style: AppTypography.bodyStrong.copyWith(color: action.tone == StopSheetTone.danger ? AppColors.dangerText : null),
                          ),
                        ),
                        if (action.onceScope) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(5)),
                            child: Text('이번만', style: AppTypography.caption.copyWith(fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ],
                    ),
                    if (action.description != null) Text(action.description!, style: AppTypography.caption),
                  ],
                ),
              ),
              if (action.chevron) const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}

/// 4단계 결과에서 장소를 누를 때.
/// AI 장소: 바꾸기 · 추천 이유 · 이 코스에서 빼기(이번만) · 장소 정보 / 앞으로 추천하지 않기(차단).
/// 가장 많이 쓸 바꾸기를 맨 위에 둔다(07 D60).
/// 내가 고른 장소: 장소 정보 · 이 코스에서 빼기 (차단 없음, 저장됨에는 그대로).
Future<void> showResultStopSheet(
  BuildContext context, {
  required CourseStop stop,
  required VoidCallback onInfo,
  required VoidCallback onRemove,
  VoidCallback? onSwap,
  VoidCallback? onBlock,
}) {
  final info = StopSheetAction(label: '장소 정보 보기', icon: Icons.place_outlined, onTap: onInfo, tone: StopSheetTone.link, chevron: true);
  if (!stop.isAi) {
    return showStopSheet(context, stop: stop, groups: [
      [info, _removeOwn(onRemove)],
    ]);
  }
  return showStopSheet(context, stop: stop, reasonAfter: onSwap != null ? 1 : 0, groups: [
    [
      if (onSwap != null)
        StopSheetAction(
          label: '다른 곳으로 바꾸기',
          description: '이 자리에 다른 장소를 추천해요',
          icon: Icons.swap_horiz_rounded,
          tone: StopSheetTone.ai,
          onceScope: true,
          onTap: onSwap,
        ),
      _removeAi(onRemove),
      info,
    ],
    if (onBlock != null) [_block(onBlock)],
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
      tone: StopSheetTone.danger,
      onTap: onTap,
    );
