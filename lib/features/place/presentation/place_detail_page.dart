import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/utils/external_link.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/widgets/headers.dart';
import '../../../core/widgets/overlays.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/surfaces.dart';
import '../../saved/presentation/saved_providers.dart';
import '../../saved/presentation/widgets/collection_picker_sheet.dart';
import '../domain/place.dart';

/// #20 장소 상세
class PlaceDetailPage extends ConsumerWidget {
  const PlaceDetailPage({super.key, required this.placeId});
  final String placeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(placeDetailProvider(placeId));
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SubPageHeader(
              title: '장소 상세',
              trailing: IconButton(
                tooltip: '공유',
                icon: const Icon(Icons.ios_share_rounded, color: AppColors.textPrimary),
                // 공유 동작은 확정 필요 (docs/05 #20)
                onPressed: () => showAppSnackBar(context, '장소 공유는 준비 중이에요.'),
              ),
            ),
            Expanded(
              child: AsyncValueView<PlaceDetail>(
                value: detail,
                onRetry: () => ref.invalidate(placeDetailProvider(placeId)),
                data: (d) => _Body(detail: d),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final status = [
      if (place.rating != null) '★ ${place.rating!.toStringAsFixed(1)}',
      ?detail.openStatusLabel,
      ?detail.closingLabel,
    ].join(' · ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xs, AppSpacing.screenH, AppSpacing.xxl),
      children: [
        AspectRatio(
          aspectRatio: 16 / 9.5,
          child: AppNetworkImage(url: place.imageUrl, radius: AppRadius.card, width: double.infinity),
        ),
        Transform.translate(
          offset: const Offset(0, -18),
          child: AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(place.name, style: AppTypography.display),
                      const SizedBox(height: 4),
                      Text('${place.displayArea} · ${place.categoryLabel}', style: AppTypography.body),
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
                  onPressed: () => _changeCollections(context),
                ),
              ],
            ),
          ),
        ),
        Text('장소 정보', style: AppTypography.section),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              _InfoRow(label: '주소', child: Text(place.address, style: AppTypography.bodyStrong)),
              if (place.keywords.isNotEmpty)
                _InfoRow(label: '키워드', child: TagWrap(place.keywords, tone: AppTagTone.primary)),
              if (place.sourceUrl != null)
                _InfoRow(
                  label: '원본',
                  child: AppTextLink(
                    label: 'Instagram 게시물 보기',
                    trailingChevron: true,
                    onPressed: () => openExternalLink(context, place.sourceUrl!),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('이 장소로 무엇을 할까요?', style: AppTypography.section),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: '보관함 변경',
                variant: AppButtonVariant.white,
                onPressed: () => _changeCollections(context),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppButton.dark(
                label: '코스 만들기',
                // 해당 장소를 사전 선택해 코스 만들기 1/4로 (docs/04 §D)
                onPressed: () => context.push(AppRoutes.courseNewInfo, extra: [place]),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 64, child: Text(label, style: AppTypography.meta.copyWith(fontWeight: FontWeight.w700))),
          Expanded(child: Align(alignment: Alignment.centerLeft, child: child)),
        ],
      ),
    );
  }
}
