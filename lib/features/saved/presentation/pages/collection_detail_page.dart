import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/repositories.dart';
import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/bottom_cta.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/headers.dart';
import '../../../../core/widgets/overlays.dart';
import '../../../../core/widgets/states.dart';
import '../../../../core/widgets/surfaces.dart';
import '../../../course/presentation/course_draft_controller.dart';
import '../../../course/presentation/pages/add_places_page.dart';
import '../../../place/domain/place.dart';
import '../../domain/saved_models.dart';
import '../saved_providers.dart';
import '../widgets/place_list_tile.dart';

/// #16 빈 보관함 / #17 보관함 상세
class CollectionDetailPage extends ConsumerStatefulWidget {
  const CollectionDetailPage({super.key, required this.collectionId});
  final String collectionId;

  @override
  ConsumerState<CollectionDetailPage> createState() => _CollectionDetailPageState();
}

class _CollectionDetailPageState extends ConsumerState<CollectionDetailPage> {
  // 보관함 안 검색 · 정렬은 서버 보관함 API가 생기면 다시 넣는다 (NEEDS BACKEND)
  SavedPlaceQuery get _query => SavedPlaceQuery(collectionId: widget.collectionId);

  Future<void> _addFromSaved(List<String> existing) async {
    final picked = await context.push<List<Place>>(
      AppRoutes.pickPlaces,
      extra: AddPlacesArgs(title: '보관함에 장소 추가', excludedPlaceIds: existing.toSet(), excludedLabel: '보관함에 있음', ctaLabel: '보관함에 추가'),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    try {
      await ref.read(savedRepositoryProvider).addPlacesToCollection(
            collectionId: widget.collectionId,
            placeIds: picked.map((p) => p.id).toList(),
          );
      invalidateSavedData(ref);
      if (mounted) showAppSnackBar(context, '${picked.length}곳을 보관함에 추가했어요.');
    } catch (e) {
      if (mounted) showAppSnackBar(context, failureMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final collectionValue = ref.watch(collectionProvider(widget.collectionId));
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AsyncValueView<PlaceCollection>(
          value: collectionValue,
          onRetry: () => ref.invalidate(collectionProvider(widget.collectionId)),
          data: (collection) => Column(
            children: [
              PlainHeader(
                title: collection.name,
                actions: [
                  IconButton(
                    tooltip: '보관함 메뉴',
                    icon: const Icon(Icons.more_horiz_rounded, color: AppColors.textPrimary),
                    // 보관함 ⋯ 메뉴(이름 변경·삭제)는 디자인/정책 확정 필요 (docs/07 §3)
                    onPressed: () => showAppSnackBar(context, '보관함 관리 메뉴는 준비 중이에요.'),
                  ),
                ],
              ),
              Expanded(child: collection.placeCount == 0 ? _empty(collection) : _detail(collection)),
            ],
          ),
        ),
      ),
    );
  }

  /// 이름 · 업데이트 · 장소 개수 · 지도 보기. 비어 있을 때와 장소가 있을 때 같은 모양이다.
  Widget _summaryCard(PlaceCollection collection) {
    final empty = collection.placeCount == 0;
    final updated = collection.updatedAt == null ? null : formatRelative(collection.updatedAt!);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(collection.name, style: AppTypography.section),
                const SizedBox(height: 4),
                Text(
                  [
                    if (empty) '방금 생성됨' else if (updated != null) '최근 업데이트 $updated',
                    '장소 ${collection.placeCount}곳',
                  ].join(' · '),
                  style: AppTypography.meta,
                ),
              ],
            ),
          ),
          // 저장한 곳이 없어도 지도는 열 수 있다 (07 D32)
          AppButton(
            label: '지도 보기',
            variant: AppButtonVariant.soft,
            icon: Icons.map_outlined,
            expand: false,
            height: 40,
            onPressed: () => context.push(AppRoutes.collectionMap(collectionId: collection.id)),
          ),
        ],
      ),
    );
  }

  Widget _placesHeader(PlaceCollection collection, {required VoidCallback onAdd}) {
    return SectionHeader(
      title: '저장된 장소',
      trailingText: '${collection.placeCount}곳',
      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.sm),
      trailing: IconButton(tooltip: '장소 추가', icon: const Icon(Icons.add_rounded, color: AppColors.primary), onPressed: onAdd),
    );
  }

  /// 빈 안내: 장소 카드가 들어갈 자리에 같은 카드로 둔다
  Widget _emptyCard() {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        children: [
          Text('아직 담은 장소가 없어요', style: AppTypography.cardTitle, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          Text('저장한 장소에서 고르거나\n링크로 새 장소를 찾아 담을 수 있어요.', style: AppTypography.meta, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          AppButton(label: '저장한 장소에서 추가하기', onPressed: () => _addFromSaved(const [])),
          const SizedBox(height: AppSpacing.xs),
          AppButton.outline(label: '링크로 장소 찾기', onPressed: () => context.go(AppRoutes.extract)),
        ],
      ),
    );
  }

  Widget _empty(PlaceCollection collection) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.lg),
      children: [
        _summaryCard(collection),
        _placesHeader(collection, onAdd: () => _addFromSaved(const [])),
        _emptyCard(),
      ],
    );
  }

  Widget _detail(PlaceCollection collection) {
    final places = ref.watch(savedPlacesProvider(_query));
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.lg),
            children: [
              _summaryCard(collection),
              _placesHeader(
                collection,
                onAdd: () => _addFromSaved(places.value?.map((i) => i.place.id).toList() ?? const []),
              ),
              AsyncValueView<List<SavedPlaceItem>>(
                value: places,
                compactError: true,
                loading: const SkeletonList(padding: EdgeInsets.zero),
                onRetry: () => ref.invalidate(savedPlacesProvider(_query)),
                isEmpty: (l) => l.isEmpty,
                empty: _emptyCard(),
                data: (list) => Column(
                  children: [
                    for (final item in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: PlaceListTile(
                          place: item.place,
                          showBookmark: false,
                          subtitle: [
                            item.place.categoryLabel,
                            // 카테고리와 같은 키워드는 건너뛴다 ("한식 · 한식" 방지)
                            ?item.place.keywords.where((k) => k != item.place.categoryLabel).firstOrNull,
                            if (item.place.rating != null) '★ ${item.place.rating!.toStringAsFixed(1)}',
                          ].join(' · '),
                          footer: const SizedBox.shrink(),
                          onTap: () => context.push(AppRoutes.place(item.place.id)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        BottomCta(
          child: AppButton.dark(
            label: '이 보관함으로 코스 만들기',
            // 보관함 장소를 일괄로 불러와 코스 만들기 1/4로 (docs/04 §D)
            onPressed: places.hasValue
                ? () => startCourseWizard(context, ref, places: places.value!.map((i) => i.place).toList())
                : null,
          ),
        ),
      ],
    );
  }
}
