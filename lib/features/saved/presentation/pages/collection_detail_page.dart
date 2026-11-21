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
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/headers.dart';
import '../../../../core/widgets/overlays.dart';
import '../../../../core/widgets/states.dart';

import '../../../course/presentation/course_draft_controller.dart';
import '../../../course/presentation/pages/add_places_page.dart';
import '../../../place/domain/place.dart';
import '../../domain/saved_models.dart';
import '../saved_providers.dart';
import '../widgets/saved_rows.dart';

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
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      await ref.read(savedRepositoryProvider).addPlacesToCollection(collectionId: widget.collectionId, placeIds: picked.map((p) => p.id).toList());
      // 추가하는 중에 화면을 나갔어도 목록은 맞춰 둔다
      invalidateSavedDataIn(container);
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
                // v2: 이름은 머리가 아니라 표지 아래에 크게
                title: '',
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

  /// v2: 큰 표지 콜라주(사진이 있을 때) → 이름 26 → 'n곳 · 수정' → '지도로 보기' · '장소 담기' 칩. 비어 있을 때도 같은 자리.
  Widget _summaryCard(PlaceCollection collection, {required VoidCallback onAdd}) {
    Widget chip(IconData icon, String label, VoidCallback onPressed) => ActionChip(
      avatar: Icon(icon, size: 16, color: AppColors.textPrimary),
      label: Text(label, style: AppTypography.labelLarge),
      backgroundColor: AppColors.fill,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      onPressed: onPressed,
    );
    final empty = collection.placeCount == 0;
    final updated = collection.updatedAt == null ? null : formatRelative(collection.updatedAt!);
    final urls = collection.thumbnailUrls;
    Widget tile(int i) => i < urls.length ? AppNetworkImage(url: urls[i], radius: 0) : const ColoredBox(color: AppColors.fill);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (urls.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 170,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 2, child: tile(0)),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: tile(1)),
                        const SizedBox(height: 3),
                        Expanded(child: tile(2)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],
        Text(collection.name, style: AppTypography.display),
        const SizedBox(height: 4),
        Text(['${collection.placeCount}곳', if (empty) '방금 만듦' else if (updated != null) '$updated 수정'].join(' · '), style: AppTypography.meta),
        const SizedBox(height: 14),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            // 저장한 곳이 없어도 지도는 열 수 있다 (07 D32)
            chip(Icons.map_outlined, '지도로 보기', () => context.push(AppRoutes.collectionMap(collectionId: collection.id))),
            chip(Icons.add_rounded, '장소 담기', onAdd),
          ],
        ),
      ],
    );
  }

  /// 빈 안내: 장소 행이 들어갈 자리에 회색 판으로 둔다 (v2)
  Widget _emptyCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.lg),
      decoration: BoxDecoration(color: AppColors.fill, borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          Text('아직 담은 장소가 없어요', style: AppTypography.cardTitle, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          Text('저장한 장소에서 고르거나\n링크로 새 장소를 찾아 담을 수 있어요.', style: AppTypography.meta, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          AppButton(label: '저장한 장소에서 추가하기', onPressed: () => _addFromSaved(const [])),
          const SizedBox(height: AppSpacing.xs),
          AppButton(variant: AppButtonVariant.white, label: '링크로 장소 찾기', onPressed: () => context.go(AppRoutes.extract)),
        ],
      ),
    );
  }

  Widget _empty(PlaceCollection collection) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.lg),
      children: [
        _summaryCard(collection, onAdd: () => _addFromSaved(const [])),
        const SizedBox(height: AppSpacing.lg),
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
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            children: [
              Padding(
                padding: AppSpacing.screenPadding,
                child: _summaryCard(collection, onAdd: () => _addFromSaved(places.value?.map((i) => i.place.id).toList() ?? const [])),
              ),
              const SizedBox(height: AppSpacing.sm),
              // v2: 장소는 화면 끝까지 가는 선 없는 행 (저장됨 탭과 같은 SavedPlaceRow, 바깥 4 + 안쪽 16 = 20)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                child: AsyncValueView<List<SavedPlaceItem>>(
                  value: places,
                  compactError: true,
                  loading: const SkeletonList(padding: EdgeInsets.zero),
                  onRetry: () => ref.invalidate(savedPlacesProvider(_query)),
                  isEmpty: (l) => l.isEmpty,
                  empty: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: _emptyCard(),
                  ),
                  data: (list) => Column(
                    children: [for (final item in list) SavedPlaceRow(place: item.place, onTap: () => context.push(AppRoutes.place(item.place.id)))],
                  ),
                ),
              ),
            ],
          ),
        ),
        BottomCta(
          child: AppButton(
            label: '이 보관함으로 코스 만들기',
            icon: Icons.route_rounded,
            // 보관함 장소를 일괄로 불러와 코스 만들기 1/4로 (docs/04 §D)
            onPressed: places.hasValue ? () => startCourseWizard(context, ref, places: places.value!.map((i) => i.place).toList()) : null,
          ),
        ),
      ],
    );
  }
}
