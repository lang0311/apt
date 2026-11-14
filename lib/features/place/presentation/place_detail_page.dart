import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/repositories.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/error/app_failure.dart';
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
import '../../saved/presentation/widgets/saved_rows.dart';
import '../domain/place.dart';

/// #20 장소 상세: 일반 헤더(뒤로 · 장소 상세 · 공유) → 사진(있을 때) → 이름 카드(저장 버튼, 추천받은 곳이면 ✦ 코스 이름) →
/// 장소 정보(값이 있는 줄만) → 담은 보관함, 하단 고정 '이 장소로 코스 만들기'
class PlaceDetailPage extends ConsumerWidget {
  const PlaceDetailPage({super.key, required this.placeId});
  final String placeId;

  static const _photoHeight = 200.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(placeDetailProvider(placeId));
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 일반 헤더 (불러오는 중 · 오류에도 뒤로 갈 수 있다)
            PlainHeader(
              title: '장소 상세',
              onLeading: () => popOrGoHome(context),
              actions: [
                IconButton(
                  tooltip: '공유',
                  // 공유 동작은 확정 필요 (docs/05 #20)
                  onPressed: () => showAppSnackBar(context, '장소 공유는 준비 중이에요.'),
                  icon: const Icon(Icons.ios_share_rounded, color: AppColors.textPrimary, size: 22),
                ),
              ],
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

  /// 저장 버튼. 보관함이 없는 서버 모드에서 저장된 장소는 바로 저장을 해제하고 되돌리기를 준다 (07 D41).
  /// 그 밖에는 보관함 시트(저장 · 변경)를 연다.
  Future<void> _onSaveButton(BuildContext context, WidgetRef ref) async {
    if (!place.isSaved || ref.read(collectionsSupportedProvider)) return _changeCollections(context);
    // 해제 뒤 화면이 새로 그려져도 되돌리기가 동작하도록 미리 잡아 둔다
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(savedRepositoryProvider);
    final id = place.id;
    try {
      await repo.unsavePlace(id);
    } catch (e) {
      if (context.mounted) showAppSnackBar(context, failureMessage(e));
      return;
    }
    if (context.mounted) {
      showAppSnackBar(
        context,
        '저장을 해제했어요.',
        actionLabel: '되돌리기',
        onAction: () async {
          try {
            await repo.savePlaces(placeIds: [id], collectionIds: const []);
            invalidateSavedDataIn(container);
          } catch (e) {
            messenger.showSnackBar(SnackBar(content: Text(failureMessage(e))));
          }
        },
      );
    }
    invalidateSavedDataIn(container);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 서버 모드에는 보관함이 없다(목록이 비면 카드를 숨긴다)
    final collections = ref.watch(collectionsProvider).value ?? const [];
    final names = [
      for (final c in collections)
        if (detail.collectionIds.contains(c.id)) c.name,
    ];

    // 추천받아 저장된 곳이면 어느 코스에서 왔는지 (저장됨 AI 추천 탭과 같은 값, 07 D44)
    final aiItem = ref.watch(aiSavedPlacesProvider).value?.where((i) => i.place.id == place.id).firstOrNull;
    final recommendedIn = aiItem == null ? null : SavedPlaceRow.recommendedLabel(aiItem.recommendedIn);
    // 값이 없는 줄은 숨긴다 (추천받은 곳은 주소가 비어 있을 수 있다)
    final infoRows = <Widget>[
      if (place.address.trim().isNotEmpty) _InfoRow(label: '주소', child: Text(place.address, style: AppTypography.body)),
      if (place.phone != null)
        _InfoRow(label: '전화', onTap: () => openDialer(context, place.phone!), child: Text(place.phone!, style: AppTypography.bodyStrong)),
      if (place.keywords.isNotEmpty) _InfoRow(label: '키워드', child: TagWrap(place.keywords, tone: AppTagTone.primary)),
      if (place.mapUrl != null)
        _InfoRow(label: '지도', onTap: () => openExternalLink(context, place.mapUrl!), child: Text('카카오맵에서 보기', style: AppTypography.bodyStrong)),
      if (place.sourceUrl != null)
        _InfoRow(label: '원본', onTap: () => openExternalLink(context, place.sourceUrl!), child: Text('Instagram 게시물', style: AppTypography.bodyStrong)),
    ];

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            children: [
              // 사진이 있으면 이름 카드 위에, 없으면 이름 카드부터
              if (place.imageUrl != null && place.imageUrl!.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xs, AppSpacing.screenH, 0),
                  child: PlaceImage(place: place, width: double.infinity, height: PlaceDetailPage._photoHeight, radius: AppRadius.card, iconSize: 40),
                ),
                const SizedBox(height: AppSpacing.sm),
              ] else
                const SizedBox(height: AppSpacing.xs),
              Padding(
                padding: AppSpacing.screenPadding,
                child: _TitleCard(detail: detail, recommendedIn: recommendedIn, onSave: () => _onSaveButton(context, ref)),
              ),
              if (infoRows.isNotEmpty) ...[
                const SectionHeader(title: '장소 정보', padding: EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.lg, AppSpacing.screenH, AppSpacing.xs)),
                Padding(
                  padding: AppSpacing.screenPadding,
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                    child: DividedRows(indent: SectionCard.innerPadding, children: infoRows),
                  ),
                ),
              ],
              if (place.isSaved && collections.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding: AppSpacing.screenPadding,
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
  const _TitleCard({required this.detail, required this.onSave, this.recommendedIn});
  final PlaceDetail detail;
  final VoidCallback onSave;

  /// "test3 코스에서 추천" — 추천받아 저장된 곳만 (✦ · 주황은 AI 추천 표시 전용)
  final String? recommendedIn;

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
                Text(place.name, style: AppTypography.title.copyWith(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text([place.categoryLabel, if (place.shortArea.isNotEmpty) place.shortArea].join(' · '), style: AppTypography.body),
                if (status.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(status, style: AppTypography.label.copyWith(color: AppColors.primary)),
                ],
                if (recommendedIn != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 13, color: AppColors.ai),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '$recommendedIn받은 곳이에요',
                          style: AppTypography.caption.copyWith(color: AppColors.aiText, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          AppButton(
            label: place.isSaved ? '저장됨' : '저장하기',
            variant: place.isSaved ? AppButtonVariant.soft : AppButtonVariant.outline,
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
