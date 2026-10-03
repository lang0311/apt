import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/headers.dart';
import '../../../../core/widgets/overlays.dart';
import '../../../../core/widgets/segmented_tabs.dart';
import '../../../../core/widgets/states.dart';
import '../../../../core/widgets/surfaces.dart';
import '../../domain/saved_models.dart';
import '../saved_providers.dart';
import '../widgets/category_style.dart';
import '../widgets/category_tile.dart';
import '../widgets/collection_card.dart';
import '../widgets/create_collection_modal.dart';
import '../widgets/place_list_tile.dart';

/// #13 / #14 저장됨 — [카테고리 | 내 보관함]
class SavedPage extends ConsumerStatefulWidget {
  const SavedPage({super.key});

  @override
  ConsumerState<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends ConsumerState<SavedPage> {
  int _tab = 0;
  String? _categoryKey;

  Future<void> _createCollection() async {
    final created = await showCreateCollectionModal(context);
    if (created != null && mounted) context.push(AppRoutes.collection(created.id));
  }

  Future<void> _refresh() async {
    invalidateSavedData(ref);
    await ref.read(savedSummaryProvider.future).catchError((_) => const SavedSummary(totalCount: 0, categories: []));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 110),
                children: [
                  PageTitleHeader(
                    title: '저장됨',
                    subtitle: '가고 싶은 장소를 한곳에 모아보세요.',
                    trailing: _tab == 1
                        ? AppIconBox(icon: Icons.add_rounded, size: 44, tooltip: '새 보관함 만들기', onPressed: _createCollection)
                        : null,
                  ),
                  Padding(
                    padding: AppSpacing.screenPadding,
                    child: SegmentedTabs(
                      labels: const ['카테고리', '내 보관함'],
                      selectedIndex: _tab,
                      onChanged: (i) => setState(() => _tab = i),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_tab == 0)
                    _CategoryTab(
                      selectedKey: _categoryKey,
                      onSelect: (k) => setState(() => _categoryKey = k),
                    )
                  else
                    _CollectionsTab(onCreate: _createCollection),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: AppSpacing.lg,
              child: Center(
                child: FloatingPillButton(
                  label: '지도에서 보기',
                  icon: Icons.map_outlined,
                  // 현재 탭 맥락으로 바로 지도 진입 (docs/04 §C)
                  onPressed: () => context.push(
                    _tab == 0 ? AppRoutes.categoryMap(categoryKey: _categoryKey) : AppRoutes.collectionMap(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTab extends ConsumerWidget {
  const _CategoryTab({required this.selectedKey, required this.onSelect});
  final String? selectedKey;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(savedSummaryProvider);
    final places = ref.watch(savedPlacesProvider(SavedPlaceQuery(categoryKey: selectedKey)));
    final selectedLabel = summary.value?.categories.where((c) => c.key == selectedKey).firstOrNull?.label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AsyncValueView(
          value: summary,
          compactError: true,
          onRetry: () => ref.invalidate(savedSummaryProvider),
          loading: const Padding(padding: AppSpacing.screenPadding, child: SkeletonBox(height: 200, radius: 20)),
          data: (s) => Padding(
            padding: AppSpacing.screenPadding,
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1.45,
              children: [
                CategoryTile(
                  label: '전체',
                  count: s.totalCount,
                  style: const CategoryStyle(Icons.bookmark_border_rounded, AppColors.primary),
                  selected: selectedKey == null,
                  onTap: () => onSelect(null),
                ),
                for (final c in s.categories)
                  CategoryTile(
                    label: c.label,
                    count: c.count,
                    style: CategoryStyle.of(c.key),
                    selected: selectedKey == c.key,
                    onTap: () => onSelect(c.key),
                  ),
              ],
            ),
          ),
        ),
        SectionHeader(
          title: selectedLabel == null ? '전체 저장 장소' : '$selectedLabel 저장 장소',
          trailing: AppButton(
            label: '지도 보기',
            icon: Icons.map_outlined,
            variant: AppButtonVariant.soft,
            expand: false,
            height: 36,
            onPressed: () => context.push(AppRoutes.categoryMap(categoryKey: selectedKey)),
          ),
        ),
        AsyncValueView(
          value: places,
          onRetry: () => ref.invalidate(savedPlacesProvider),
          loading: const SkeletonList(),
          isEmpty: (list) => list.isEmpty,
          empty: AppEmptyState(
            compact: true,
            title: '아직 저장한 장소가 없어요',
            description: 'SNS 게시물 링크로 가고 싶은 곳을 저장해보세요.',
            actionLabel: '장소 추출하기',
            onAction: () => context.go(AppRoutes.extract),
          ),
          data: (list) => Padding(
            padding: AppSpacing.screenPadding,
            child: Column(
              children: [
                for (final item in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: PlaceListTile(place: item.place, onTap: () => context.push(AppRoutes.place(item.place.id))),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CollectionsTab extends ConsumerWidget {
  const _CollectionsTab({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collections = ref.watch(collectionsProvider);
    final total = ref.watch(savedSummaryProvider).value?.totalCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: AppSpacing.screenPadding,
          child: InfoCard(
            title: '새 보관함 만들기',
            titleColor: AppColors.primary,
            description: '여행이나 취향별로 장소를 정리해요.',
            onTap: onCreate,
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
          ),
        ),
        SectionHeader(title: '내 보관함', trailingText: collections.hasValue ? '${collections.value!.length}개' : null),
        AsyncValueView(
          value: collections,
          onRetry: () => ref.invalidate(collectionsProvider),
          loading: const SkeletonList(),
          isEmpty: (list) => list.isEmpty,
          empty: const AppEmptyState(
            compact: true,
            icon: Icons.folder_outlined,
            title: '아직 만든 보관함이 없어요',
            description: '목적별로 장소를 모아두면 코스 만들 때 한 번에 불러올 수 있어요.',
          ),
          data: (list) => Padding(
            padding: AppSpacing.screenPadding,
            child: Column(
              children: [
                for (final c in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: CollectionCard(
                      collection: c,
                      onTap: () => context.push(AppRoutes.collection(c.id)),
                      // 보관함 ⋯ 메뉴(이름 변경·삭제)는 디자인/정책 확정 필요 (docs/07 §3)
                      onMore: () => showAppSnackBar(context, '보관함 관리 메뉴는 준비 중이에요.'),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xs, AppSpacing.screenH, 0),
          child: AppCard(
            onTap: () => context.push(AppRoutes.categoryMap()),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                const IconCircle(icon: Icons.folder_outlined),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('전체 저장 장소', style: AppTypography.bodyStrong),
                      Text('보관함과 관계없이 모두 보기', style: AppTypography.caption),
                    ],
                  ),
                ),
                if (total != null) Text('$total곳', style: AppTypography.label.copyWith(color: AppColors.primary)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
