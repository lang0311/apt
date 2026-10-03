import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/bottom_cta.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/headers.dart';
import '../../../saved/presentation/widgets/saved_place_picker.dart';
import '../course_draft_controller.dart';

/// #24 저장한 장소 선택 (2/4). 선택 순서대로 번호가 붙고, 사전 선택(장소 상세/보관함 진입)이 반영된다.
class PlaceSelectionPage extends ConsumerWidget {
  const PlaceSelectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(courseDraftProvider);
    final notifier = ref.read(courseDraftProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const StepHeader(title: '저장한 장소 선택', step: 2),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.lg, AppSpacing.screenH, AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('코스에 넣을 장소를 골라주세요', style: AppTypography.title),
                  const SizedBox(height: 4),
                  Text('SNS에서 저장한 장소를 여러 개 선택할 수 있어요.', style: AppTypography.body),
                ],
              ),
            ),
            Expanded(
              child: SavedPlacePicker(
                selectedIds: draft.places.map((p) => p.id).toList(),
                style: PickerSelectionStyle.numbered,
                onToggle: (p) => notifier.update(
                  (d) => d.placeIds.contains(p.id) ? d.removePlace(p.id) : d.addPlaces([p]),
                ),
              ),
            ),
            BottomCta(
              child: AppButton(
                label: '선택한 장소로 계속하기 (${draft.places.length})',
                // 0곳 진행 허용 여부는 정책 확인 필요 — 우선 1곳 이상일 때만 진행
                onPressed: draft.hasPlaces ? () => context.push(AppRoutes.courseNewCompanion) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
