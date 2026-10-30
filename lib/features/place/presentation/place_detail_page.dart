import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/utils/external_link.dart';
import '../../../core/widgets/bottom_cta.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/widgets/headers.dart';
import '../../../core/widgets/overlays.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/surfaces.dart';
import '../../course/presentation/course_draft_controller.dart';
import '../../saved/presentation/saved_providers.dart';
import '../../saved/presentation/widgets/collection_picker_sheet.dart';
import '../../saved/presentation/widgets/place_image.dart';
import '../domain/place.dart';

/// #20 장소 상세: 맨 위 사진(뒤로 · 공유는 사진 위 흰 원) → 사진에 살짝 겹친 이름 카드(저장 버튼) →
/// 장소 정보 → 담은 보관함, 하단 고정 '이 장소로 코스 만들기'
class PlaceDetailPage extends ConsumerWidget {
  const PlaceDetailPage({super.key, required this.placeId});
  final String placeId;

  static const _photoHeight = 250.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(placeDetailProvider(placeId));
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: AsyncValueView<PlaceDetail>(
                value: detail,
                onRetry: () => ref.invalidate(placeDetailProvider(placeId)),
                data: (d) => _Body(detail: d),
              ),
            ),
            // 불러오는 중 · 오류에도 뒤로 갈 수 있게 버튼은 항상 위에 둔다
            Positioned(
              top: AppSpacing.xs,
              left: AppSpacing.sm,
              right: AppSpacing.sm,
              child: Row(
                children: [
                  _PhotoButton(icon: Icons.chevron_left_rounded, tooltip: '뒤로', onPressed: () => popOrGoHome(context)),
                  const Spacer(),
                  _PhotoButton(
                    icon: Icons.ios_share_rounded,
                    tooltip: '공유',
                    // 공유 동작은 확정 필요 (docs/05 #20)
                    onPressed: () => showAppSnackBar(context, '장소 공유는 준비 중이에요.'),
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

/// 사진 위 흰 원 버튼
class _PhotoButton extends StatelessWidget {
  const _PhotoButton({required this.icon, required this.tooltip, required this.onPressed});
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceRaised.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: AppColors.textPrimary, size: icon == Icons.chevron_left_rounded ? 28 : 22),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.detail});
  final PlaceDetail detail;

  Place get place => detail.place;

  Future<void> _changeCollections(BuildContext context) async {
    final ok = await showCollectionPickerSheet(
      context,
      places: [place],
      mode: place.isSaved ? CollectionPickerMode.change : CollectionPickerMode.save,
      initialSelected: detail.collectionIds.toSet(),
    );
    if (ok == true && context.mounted) showAppSnackBar(context, place.isSaved ? '보관함을 변경했어요.' : '장소를 저장했어요.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 서버 모드에는 보관함이 없다(목록이 비면 카드를 숨긴다)
    final collections = ref.watch(collectionsProvider).value ?? const [];
    final names = [
      for (final c in collections)
        if (detail.collectionIds.contains(c.id)) c.name,
    ];

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            children: [
              Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: PlaceDetailPage._photoHeight,
                    child: PlaceImage(
                      place: place,
                      width: double.infinity,
                      height: PlaceDetailPage._photoHeight,
                      radius: 0,
                      iconSize: 40,
                    ),
                  ),
                  Padding(
                    // 사진 아래쪽에 28만큼 겹친다
                    padding: const EdgeInsets.fromLTRB(AppSpacing.sm, PlaceDetailPage._photoHeight - 28, AppSpacing.sm, 0),
                    child: _TitleCard(detail: detail, onSave: () => _changeCollections(context)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: SectionCard(
                  title: '장소 정보',
                  child: DividedRows(
                    indent: SectionCard.innerPadding,
                    children: [
                      _InfoRow(label: '주소', child: Text(place.address, style: AppTypography.body)),
                      if (place.keywords.isNotEmpty)
                        _InfoRow(label: '키워드', child: TagWrap(place.keywords, tone: AppTagTone.primary)),
                      if (place.sourceUrl != null)
                        _InfoRow(
                          label: '원본',
                          onTap: () => openExternalLink(context, place.sourceUrl!),
                          child: Text('Instagram 게시물', style: AppTypography.bodyStrong),
                        ),
                    ],
                  ),
                ),
              ),
              if (place.isSaved && collections.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: SectionCard(
                    title: '담은 보관함',
                    trailing: TextButton(
                      onPressed: () => _changeCollections(context),
                      style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                      child: Text('변경', style: AppTypography.label.copyWith(color: AppColors.primary)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: SectionCard.innerPadding),
                      child: Text(
                        names.isEmpty ? '아직 담은 보관함이 없어요' : names.join(' · '),
                        style: names.isEmpty ? AppTypography.meta : AppTypography.body,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        BottomCta(
          child: AppButton(
            label: '이 장소로 코스 만들기',
            // 해당 장소를 사전 선택해 코스 만들기 1/4로 (docs/04 §D)
            onPressed: () => startCourseWizard(context, ref, places: [place]),
          ),
        ),
      ],
    );
  }
}

/// 이름 · 카테고리 · 동네 · 평점 · 영업 상태 + 저장 버튼
class _TitleCard extends StatelessWidget {
  const _TitleCard({required this.detail, required this.onSave});
  final PlaceDetail detail;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final place = detail.place;
    final status = [
      if (place.rating != null) '★ ${place.rating!.toStringAsFixed(1)}',
      ?detail.openStatusLabel,
      ?detail.closingLabel,
    ].join(' · ');
    return AppCard(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(place.name, style: AppTypography.display),
                const SizedBox(height: 4),
                Text([place.categoryLabel, if (place.displayArea.isNotEmpty) place.displayArea].join(' · '), style: AppTypography.body),
                if (status.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(status, style: AppTypography.label.copyWith(color: AppColors.primary)),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          AppButton(
            label: place.isSaved ? '저장됨' : '저장하기',
            variant: place.isSaved ? AppButtonVariant.dark : AppButtonVariant.outline,
            icon: place.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            expand: false,
            height: 40,
            onPressed: onSave,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.child, this.onTap});
  final String label;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: SectionCard.innerPadding, vertical: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(width: 56, child: Text(label, style: AppTypography.meta.copyWith(fontWeight: FontWeight.w700))),
          Expanded(child: Align(alignment: Alignment.centerLeft, child: child)),
          if (onTap != null) const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
        ],
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}
