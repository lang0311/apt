import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/bottom_cta.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/headers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/course_draft.dart';
import '../course_draft_controller.dart';
import '../course_providers.dart';
import '../widgets/recommendation_quota.dart';
import '../widgets/map_place_picker.dart';

/// #24 저장한 장소 고르기 (3/4, 동행 다음). 지도 위에서 고르고 "코스 추천받기"로 4단계로 간다.
/// 고른 곳은 체크와 버튼 위 이름 칩으로 보이고, 사전 선택(장소 상세/보관함에서 시작)이 반영된다.
/// 파티 코스도 내 장소만 보인다 — 파티원은 저장 후 편집에서 자기 장소를 넣는다 (07 D23).
class PlaceSelectionPage extends ConsumerWidget {
  const PlaceSelectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(courseDraftProvider);
    final notifier = ref.read(courseDraftProvider.notifier);
    // 12번: 오늘 추천 한도를 이미 다 썼으면 버튼을 막는다 (못 읽으면 막지 않음)
    final quota = ref.watch(recommendationQuotaProvider).value;
    final exhausted = quota?.exhausted ?? false;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const StepHeader(step: 3),
            const SizedBox(height: AppSpacing.xs),
            Expanded(
              child: MapPlacePicker(
                initialRegion: ref.read(pickerRegionProvider),
                selectedIds: draft.places.map((p) => p.id).toList(),
                onToggle: (p) => notifier.update((d) => d.placeIds.contains(p.id) ? d.removePlace(p.id) : d.addPlaces([p])),
              ),
            ),
            BottomCta(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (draft.hasPlaces) ...[
                    PickedChips(places: draft.places, onRemove: (p) => notifier.update((d) => d.removePlace(p.id))),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (draft.hasPlaces) ...[
                    PlaceCountStepper(
                      count: draft.coursePlaceCount,
                      picked: draft.places.length,
                      onChanged: exhausted ? null : (n) => notifier.update((d) => d.copyWith(placeCount: n)),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  AppButton(
                    label: exhausted
                        ? '오늘 추천을 다 받았어요'
                        : draft.hasPlaces
                        ? '${draft.coursePlaceCount}곳 코스 추천받기'
                        : '코스 추천받기',
                    // 0곳 진행 허용 여부는 정책 확인 필요 — 우선 1곳 이상일 때만 진행
                    onPressed: draft.hasPlaces && !exhausted ? () => context.push(AppRoutes.courseNewAi) : null,
                  ),
                  if (exhausted) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(quotaResetLabel(quota?.resetAt), style: AppTypography.meta, textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 코스 장소 수 −/+ (11번). 고른 수보다 적게 줄일 수 없고 6곳까지 (서버 `place_count` 1~6)
class PlaceCountStepper extends StatelessWidget {
  const PlaceCountStepper({super.key, required this.count, required this.picked, required this.onChanged});
  final int count;
  final int picked;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final ai = count - picked;
    final change = onChanged;
    final canMinus = change != null && count > picked.clamp(1, CourseDraft.maxPlaceCount);
    final canPlus = change != null && count < CourseDraft.maxPlaceCount;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('코스 장소 수', style: AppTypography.bodyStrong),
              Text(ai > 0 ? '고른 $picked곳 + AI 추천 $ai곳' : '고른 $picked곳만으로 동선을 짜요', style: AppTypography.meta),
            ],
          ),
        ),
        _StepButton(icon: LucideIcons.minus, tooltip: '장소 수 줄이기', onPressed: canMinus ? () => change(count - 1) : null),
        SizedBox(
          width: 48,
          child: Text('$count곳', style: AppTypography.bodyStrong, textAlign: TextAlign.center),
        ),
        _StepButton(icon: LucideIcons.plus, tooltip: '장소 수 늘리기', onPressed: canPlus ? () => change(count + 1) : null),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.tooltip, required this.onPressed});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    tooltip: tooltip,
    style: IconButton.styleFrom(
      backgroundColor: AppColors.surfaceMuted,
      disabledBackgroundColor: AppColors.surfaceMuted,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.small)),
      minimumSize: const Size(40, 40),
    ),
    icon: Icon(icon, size: 18, color: onPressed == null ? AppColors.textHint : AppColors.textPrimary),
  );
}
