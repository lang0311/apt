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
import '../../../../core/widgets/inputs.dart';
import '../../../../core/widgets/overlays.dart';
import '../../../../core/widgets/states.dart';
import '../../../../core/widgets/surfaces.dart';
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
  String _keyword = '';
  SavedSort _sort = SavedSort.recent;

  SavedPlaceQuery get _query => SavedPlaceQuery(
        collectionId: widget.collectionId,
        keyword: _keyword.isEmpty ? null : _keyword,
        sort: _sort,
      );

  Future<void> _addFromSaved(List<String> existing) async {
    final picked = await context.push<List<Place>>(
      AppRoutes.pickPlaces,
      extra: AddPlacesArgs(title: '보관함에 장소 추가', excludedPlaceIds: existing.toSet(), ctaLabel: '보관함에 추가하기'),
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

  void _pickSort() {
    showActionSheet(
      context,
      title: '정렬',
      actions: [
        for (final s in SavedSort.values)
          SheetAction(
            label: s.label,
            icon: s == _sort ? Icons.check_rounded : Icons.sort_rounded,
            onTap: () => setState(() => _sort = s),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final collection = ref.watch(collectionProvider(widget.collectionId));
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AsyncValueView<PlaceCollection>(
          value: collection,
          onRetry: () => ref.invalidate(collectionProvider(widget.collectionId)),
          data: (c) => Column(
            children: [
              SubPageHeader(
                title: c.name,
                trailing: IconButton(
                  tooltip: '보관함 메뉴',
                  icon: const Icon(Icons.more_horiz_rounded, color: AppColors.textPrimary),
                  // 보관함 ⋯ 메뉴(이름 변경·삭제)는 디자인/정책 확정 필요 (docs/07 §3)
                  onPressed: () => showAppSnackBar(context, '보관함 관리 메뉴는 준비 중이에요.'),
                ),
              ),
              Expanded(child: c.placeCount == 0 ? _empty(c) : _detail(c)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard(PlaceCollection c, {required bool empty}) {
    final updated = c.updatedAt == null ? null : formatRelative(c.updatedAt!);
    return AppCard(
      color: AppColors.primarySoft,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          if (empty) ...[
            const IconCircle(icon: Icons.folder_outlined, size: 48, background: AppColors.surface),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name, style: AppTypography.section),
                const SizedBox(height: 4),
                Text(
                  [
                    if (empty) '방금 생성됨' else if (updated != null) '최근 업데이트 $updated',
                    '장소 ${c.placeCount}곳',
                  ].join(' · '),
                  style: AppTypography.meta,
                ),
                if (empty) ...[
                  const SizedBox(height: 4),
                  Text('코스 만들 때 이 보관함을 불러올 수 있어요.', style: AppTypography.caption),
                ],
              ],
            ),
          ),
          if (!empty)
            AppButton.dark(
              label: '지도 보기',
              expand: false,
              height: 40,
              onPressed: () => context.push(AppRoutes.collectionMap(collectionId: c.id)),
            ),
        ],
      ),
    );
  }

  Widget _empty(PlaceCollection c) {
    return ListView(
      padding: AppSpacing.screenPadding,
      children: [
        _summaryCard(c, empty: true),
        AppEmptyState(
          title: '아직 저장된 장소가 없어요',
          description: '기존 저장 장소를 추가하거나\nSNS 링크에서 새로운 장소를 찾아보세요.',
          actionLabel: '저장한 장소에서 추가하기',
          onAction: () => _addFromSaved(const []),
          secondaryLabel: 'SNS 링크에서 새 장소 추출하기',
          onSecondary: () => context.go(AppRoutes.extract),
        ),
      ],
    );
  }

  Widget _detail(PlaceCollection c) {
    final places = ref.watch(savedPlacesProvider(_query));
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.lg),
            children: [
              _summaryCard(c, empty: false),
              const SizedBox(height: AppSpacing.md),
              AppSearchField(
                hint: '보관함 안에서 장소 검색',
                bordered: true,
                onChanged: (v) => setState(() => _keyword = v.trim()),
                trailing: AppButton(
                  label: _sort.label,
                  variant: AppButtonVariant.soft,
                  expand: false,
                  height: 36,
                  onPressed: _pickSort,
                ),
              ),
              SectionHeader(
                title: '저장된 장소',
                trailingText: '${c.placeCount}곳',
                padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.sm),
                trailing: IconButton(
                  tooltip: '장소 추가',
                  icon: const Icon(Icons.add_rounded, color: AppColors.primary),
                  onPressed: () => _addFromSaved(places.value?.map((i) => i.place.id).toList() ?? const []),
                ),
              ),
              AsyncValueView<List<SavedPlaceItem>>(
                value: places,
                compactError: true,
                loading: const SkeletonList(padding: EdgeInsets.zero),
                onRetry: () => ref.invalidate(savedPlacesProvider(_query)),
                isEmpty: (l) => l.isEmpty,
                empty: const AppEmptyState(compact: true, icon: Icons.search_off_rounded, title: '검색 결과가 없어요'),
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
                            if (item.place.keywords.isNotEmpty) item.place.keywords.first,
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
                ? () => context.push(AppRoutes.courseNewInfo, extra: places.value!.map((i) => i.place).toList())
                : null,
          ),
        ),
      ],
    );
  }
}
