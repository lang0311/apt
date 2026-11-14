import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/bottom_cta.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/headers.dart';
import '../course_draft_controller.dart';
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
                onToggle: (p) => notifier.update(
                  (d) => d.placeIds.contains(p.id) ? d.removePlace(p.id) : d.addPlaces([p]),
                ),
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
                  AppButton(
                    label: draft.hasPlaces ? '${draft.places.length}곳으로 코스 추천받기' : '코스 추천받기',
                    // 0곳 진행 허용 여부는 정책 확인 필요 — 우선 1곳 이상일 때만 진행
                    onPressed: draft.hasPlaces ? () => context.push(AppRoutes.courseNewAi) : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
