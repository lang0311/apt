import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/bottom_cta.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/headers.dart';
import '../../../../core/widgets/overlays.dart';
import '../../../../core/widgets/segmented_tabs.dart';
import '../../../../core/widgets/states.dart';
import '../../../../core/widgets/surfaces.dart';
import '../../domain/saved_models.dart';
import '../saved_providers.dart';
import '../saved_selection.dart';
import '../widgets/create_collection_modal.dart';
import '../widgets/saved_rows.dart';

/// #13 / #14 저장됨 — [카테고리 | 내 보관함 | AI 추천] (2026-10-20 개편, docs/05 #13·#14, 07 D21 · D44 · D45)
/// 카테고리 탭은 평소엔 '전체 n곳 · 필터 · 선택'만 두고, 필터를 걸었을 때만 칩 하나로 조건을 보여 준다.
/// AI 추천 탭은 코스를 저장할 때 AI 추천으로 들어온 장소다(카테고리 · 개수에는 직접 저장한 곳만).
/// 두 탭 모두 '선택'(또는 행 길게 누르기)으로 여러 곳을 골라 삭제한다.
/// 목록은 홈과 같은 SectionCard 하나 안의 구분선 행이다. 지도는 상단바 버튼 하나로만 연다.
class SavedPage extends ConsumerStatefulWidget {
  const SavedPage({super.key});

  @override
  ConsumerState<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends ConsumerState<SavedPage> {
  int _tab = 0;
  bool _deleting = false;

  /// 섹션 묶음 바깥 여백 (홈과 같은 값)
  static const _outer = AppSpacing.sm;

  Future<void> _createCollection() async {
    final created = await showCreateCollectionModal(context);
    if (created != null && mounted) context.push(AppRoutes.collection(created.id));
  }

  Future<void> _refresh() {
    invalidateSavedData(ref);
    final category = ref.read(savedCategoryFilterProvider);
    return awaitRefresh(context, [
      ref.read(savedSummaryProvider.future),
      if (_tab == 0) ref.read(savedPlacesProvider(SavedPlaceQuery(categoryKey: category)).future),
      if (_tab == 1) ref.read(collectionsProvider.future),
      if (_tab == 2) ref.read(aiSavedPlacesProvider.future),
    ]);
  }

  /// AI 추천 탭의 '지도'는 카테고리 지도(직접 저장한 곳)를 연다
  void _openMap() {
    final category = ref.read(savedCategoryFilterProvider);
    context.push(_tab == 1 ? AppRoutes.collectionMap() : AppRoutes.categoryMap(categoryKey: _tab == 0 ? category : null));
  }

  void _selectTab(int i) {
    ref.read(savedSelectionProvider.notifier).exit();
    setState(() => _tab = i);
  }

  /// 고른 곳 삭제. 카테고리는 바로 지우고 되돌리기, AI 추천은 되돌릴 수 없어 한 번 묻는다 (07 D45).
  Future<void> _deleteSelected() async {
    final ids = ref.read(savedSelectionProvider).ids.toList();
    if (ids.isEmpty || _deleting) return;
    final ai = _tab == 2;
    if (ai) {
      final ok = await showConfirmDialog(
        context,
        title: '${ids.length}곳을 삭제할까요?',
        message: 'AI가 추천해 저장된 장소는 삭제하면 되돌릴 수 없어요. 저장한 코스에는 그대로 남아요.',
        confirmLabel: '삭제',
        destructive: true,
      );
      if (!ok || !mounted) return;
    }
    setState(() => _deleting = true);
    try {
      await deleteSavedPlaces(context, ref, ids: ids, undoable: !ai);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(savedSelectionProvider);
    final count = selection.ids.length;
    return PopScope(
      // 고르는 중에 뒤로 가기를 누르면 선택만 푼다
      canPop: !selection.active,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(savedSelectionProvider.notifier).exit();
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                    children: [
                      PageTitleHeader(
                        title: '저장됨',
                        trailing: _MapButton(onPressed: _openMap),
                      ),
                      Padding(
                        padding: AppSpacing.screenPadding,
                        child: SegmentedTabs(
                          labels: const ['카테고리', '내 보관함', 'AI 추천'],
                          selectedIndex: _tab,
                          onChanged: _selectTab,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: _outer),
                        child: switch (_tab) {
                          0 => const _CategoryTab(),
                          1 => _CollectionsTab(
                            onCreate: _createCollection,
                            onShowAll: () {
                              ref.read(savedCategoryFilterProvider.notifier).select(null);
                              _selectTab(0);
                            },
                          ),
                          _ => const _AiTab(),
                        },
                      ),
                    ],
                  ),
                ),
              ),
              // 고르는 중에는 하단 탭(앱 셸이 숨김) 자리에 삭제 버튼
              if (selection.active)
                BottomCta(
                  child: AppButton.dark(
                    label: count == 0 ? '삭제' : '$count곳 삭제',
                    loading: _deleting,
                    onPressed: count == 0 ? null : _deleteSelected,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 상단바 '지도' 버튼. 저장한 곳이 없어도 켜 둔다 (07 D32).
class _MapButton extends StatelessWidget {
  const _MapButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm), side: const BorderSide(color: AppColors.border)),
      child: InkWell(
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        onTap: onPressed,
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.map_outlined, size: 18, color: AppColors.textPrimary),
                const SizedBox(width: 5),
                Text('지도', style: AppTypography.label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryTab extends ConsumerWidget {
  const _CategoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryValue = ref.watch(savedSummaryProvider);
    final selectedKey = ref.watch(savedCategoryFilterProvider);
    final places = ref.watch(savedPlacesProvider(SavedPlaceQuery(categoryKey: selectedKey)));
    final summary = summaryValue.value;
    final selected = summary?.categories.where((c) => c.key == selectedKey).firstOrNull;
    void clear() => ref.read(savedCategoryFilterProvider.notifier).select(null);

    // 저장 0곳: 필터 없이 저장 안내만
    if (summary != null && summary.totalCount == 0) {
      return SectionCard(
        title: '아직 저장한 곳이 없어요',
        child: _EmptyBody(
          message: '릴스에서 공유 → APT로 보내면 여기에 모여요.\n지도에서 검색해서 저장해도 돼요.',
          actionLabel: '장소 찾기',
          actionIcon: Icons.search_rounded,
          onAction: () => context.push(AppRoutes.placeSearch),
          secondaryLabel: '링크 붙여넣기',
          onSecondary: () => context.go(AppRoutes.extract),
        ),
      );
    }

    // 거를 것이 없으면(저장한 곳이 한 카테고리뿐) 필터를 숨긴다
    final filterable = summary != null && summary.categories.where((c) => c.count > 0).length > 1;
    final String title;
    if (summary == null) {
      title = '저장한 곳';
    } else if (selected == null) {
      title = '전체 ${summary.totalCount}곳';
    } else {
      title = '${selected.label} ${selected.count}곳';
    }

    final selection = ref.watch(savedSelectionProvider);
    final visible = places.value ?? const <SavedPlaceItem>[];
    final showFilter = summary != null && (filterable || selected != null);

    return SectionCard(
      title: selection.active ? '전체 선택' : title,
      titleWidget: selection.active ? _SelectAllTitle(items: visible) : null,
      trailing: selection.active
          ? const _DoneButton()
          : (!showFilter && visible.isEmpty)
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showFilter)
                  HeaderTextButton(
                    label: '필터',
                    icon: Icons.tune_rounded,
                    active: selected != null,
                    semanticLabel: selected == null ? '카테고리 필터' : '카테고리 필터, ${selected.label} 적용됨',
                    onPressed: () => showCategoryFilterSheet(
                      context,
                      summary: summary,
                      selectedKey: selectedKey,
                      onSelected: (key) => ref.read(savedCategoryFilterProvider.notifier).select(key),
                    ),
                  ),
                if (visible.isNotEmpty) const _SelectButton(),
              ],
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (selected != null && !selection.active)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xxs),
              child: Align(alignment: Alignment.centerLeft, child: AppliedFilterChip(label: selected.label, onClear: clear)),
            ),
          AsyncValueView(
            value: places,
            compactError: true,
            onRetry: () => ref.invalidate(savedPlacesProvider),
            loading: const _RowSkeletons(),
            isEmpty: (list) => list.isEmpty,
            empty: _EmptyBody(
              title: selected == null ? null : '${selected.label}에 저장한 곳이 없어요',
              message: '다른 카테고리를 보거나 전체로 돌아가 보세요.',
              actionLabel: '전체 보기',
              onAction: clear,
            ),
            data: (list) => DividedRows(
              indent: selection.active ? 116 : 88,
              children: [for (final item in list) _SavedRow(item: item)],
            ),
          ),
        ],
      ),
    );
  }
}

/// AI 추천 탭: 코스를 저장할 때 AI 추천으로 저장 목록에 들어온 장소 (07 D44).
/// 카테고리 탭과 같은 '전체 n곳 · 필터 · 선택' 줄을 두고, 필터는 이 탭의 장소 기준으로 센다 (07 D47).
class _AiTab extends ConsumerWidget {
  const _AiTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final places = ref.watch(aiSavedPlacesProvider);
    final summary = ref.watch(aiSavedSummaryProvider).value;
    final selectedKey = ref.watch(aiCategoryFilterProvider);
    final selection = ref.watch(savedSelectionProvider);
    final all = places.value;
    final selected = summary?.categories.where((c) => c.key == selectedKey).firstOrNull;
    // 지운 뒤 그 카테고리가 사라졌으면 전체로 본다
    final activeKey = selected?.key;
    void clear() => ref.read(aiCategoryFilterProvider.notifier).select(null);
    final visible = [
      for (final item in all ?? const <SavedPlaceItem>[])
        if (activeKey == null || categoryKeyOfPlace(item.place) == activeKey) item,
    ];
    final filterable = summary != null && summary.categories.where((c) => c.count > 0).length > 1;
    final showFilter = summary != null && (filterable || selected != null);
    final String title;
    if (all == null) {
      title = 'AI 추천';
    } else if (selected == null) {
      title = '전체 ${all.length}곳';
    } else {
      title = '${selected.label} ${visible.length}곳';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: selection.active ? '전체 선택' : title,
          titleWidget: selection.active ? _SelectAllTitle(items: visible) : null,
          trailing: selection.active
              ? const _DoneButton()
              : (!showFilter && visible.isEmpty)
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showFilter)
                      HeaderTextButton(
                        label: '필터',
                        icon: Icons.tune_rounded,
                        active: selected != null,
                        semanticLabel: selected == null ? '카테고리 필터' : '카테고리 필터, ${selected.label} 적용됨',
                        onPressed: () => showCategoryFilterSheet(
                          context,
                          summary: summary,
                          selectedKey: activeKey,
                          onSelected: (key) => ref.read(aiCategoryFilterProvider.notifier).select(key),
                        ),
                      ),
                    if (visible.isNotEmpty) const _SelectButton(),
                  ],
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (selected != null && !selection.active)
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xxs),
                  child: Align(alignment: Alignment.centerLeft, child: AppliedFilterChip(label: selected.label, onClear: clear)),
                ),
              AsyncValueView(
                value: places,
                compactError: true,
                onRetry: () => ref.invalidate(aiSavedPlacesProvider),
                loading: const _RowSkeletons(),
                isEmpty: (list) => list.isEmpty,
                empty: const _EmptyBody(
                  title: '아직 추천받아 저장한 곳이 없어요',
                  message: '코스를 저장하면 AI가 추천한 장소가 여기에 모여요.',
                ),
                data: (_) => DividedRows(
                  indent: selection.active ? 116 : 88,
                  children: [for (final item in visible) _SavedRow(item: item, fromCourse: true)],
                ),
              ),
            ],
          ),
        ),
        if (all != null && all.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, 0),
            child: Text('직접 저장하면 카테고리로 옮겨져요.', style: AppTypography.caption),
          ),
      ],
    );
  }
}

/// 저장 장소 한 행. 고르는 중이면 누르면 체크, 아니면 장소 상세. 길게 누르면 그 행을 고른 채로 선택 시작 (07 D45).
class _SavedRow extends ConsumerWidget {
  const _SavedRow({required this.item, this.fromCourse = false});
  final SavedPlaceItem item;
  final bool fromCourse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(savedSelectionProvider);
    final select = ref.read(savedSelectionProvider.notifier);
    final id = item.place.id;
    return SavedPlaceRow(
      place: item.place,
      fromCourse: fromCourse,
      recommendedIn: item.recommendedIn,
      selected: selection.active ? selection.ids.contains(id) : null,
      failed: selection.active && selection.failed.contains(id),
      onTap: selection.active ? () => select.toggle(id) : () => context.push(AppRoutes.place(id)),
      onLongPress: selection.active ? null : () => select.start(id),
    );
  }
}

/// 카드 제목 줄의 '선택' — 선택 모드로 (07 D45)
class _SelectButton extends ConsumerWidget {
  const _SelectButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      HeaderTextButton(label: '선택', semanticLabel: '여러 곳 선택해서 삭제', onPressed: () => ref.read(savedSelectionProvider.notifier).start());
}

/// 선택 모드의 '완료' — 선택을 푼다
class _DoneButton extends ConsumerWidget {
  const _DoneButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      HeaderTextButton(label: '완료', semanticLabel: '선택 끝내기', onPressed: () => ref.read(savedSelectionProvider.notifier).exit());
}

/// 선택 모드의 카드 제목: 네모 체크 '전체 선택 n/총'. 누르면 보이는 목록 전체를 고르거나 푼다.
class _SelectAllTitle extends ConsumerWidget {
  const _SelectAllTitle({required this.items});
  final List<SavedPlaceItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chosen = ref.watch(savedSelectionProvider).ids;
    final ids = [for (final item in items) item.place.id];
    final count = ids.where(chosen.contains).length;
    final all = ids.isNotEmpty && count == ids.length;
    void toggleAll() => ref.read(savedSelectionProvider.notifier).setAll(ids, selected: !all);
    return Semantics(
      button: true,
      checked: all,
      label: '전체 선택, ${ids.length}곳 중 $count곳 선택됨',
      excludeSemantics: true,
      child: InkWell(
        onTap: ids.isEmpty ? null : toggleAll,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectCheckbox(value: all, onChanged: (_) => toggleAll()),
              const SizedBox(width: AppSpacing.xs),
              Text('전체 선택', style: AppTypography.cardTitle),
              const SizedBox(width: 6),
              Text('$count/${ids.length}', style: AppTypography.meta),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionsTab extends ConsumerWidget {
  const _CollectionsTab({required this.onCreate, required this.onShowAll});
  final VoidCallback onCreate;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collections = ref.watch(collectionsProvider);
    final total = ref.watch(savedSummaryProvider).value?.totalCount;
    final count = collections.value?.length;

    return SectionCard(
      title: count == null || count == 0 ? '보관함' : '보관함 $count개',
      trailing: HeaderTextButton(label: '새 보관함', icon: Icons.add_rounded, primary: true, onPressed: onCreate),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 전체 저장 장소는 보관함 행이 아니라 안내 줄 한 줄 → 카테고리 탭 (07 D21)
          if (total != null && total > 0) AllPlacesLink(count: total, onTap: onShowAll),
          AsyncValueView(
            value: collections,
            compactError: true,
            onRetry: () => ref.invalidate(collectionsProvider),
            loading: const _RowSkeletons(),
            isEmpty: (list) => list.isEmpty,
            empty: _EmptyBody(
              title: '여행이나 취향별로 묶어 보세요',
              message: '보관함으로 묶어 두면 코스를 만들 때 한 번에 불러올 수 있어요.',
              actionLabel: '첫 보관함 만들기',
              actionIcon: Icons.add_rounded,
              onAction: onCreate,
            ),
            // 순서는 서버가 준 그대로 (NEEDS BACKEND: 최근 수정순인지, 페이지로 나눠 주는지)
            data: (list) => DividedRows(
              indent: 86,
              children: [
                for (final collection in list)
                  CollectionRow(
                    collection: collection,
                    onTap: () => context.push(AppRoutes.collection(collection.id)),
                    // 보관함 ⋯ 메뉴(이름 변경·삭제)는 디자인/정책 확정 필요 (docs/07 §3)
                    onMore: () => showAppSnackBar(context, '보관함 관리 메뉴는 준비 중이에요.'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 컨테이너 안 빈 상태: (제목) + 한두 문장 + (버튼 하나)
class _EmptyBody extends StatelessWidget {
  const _EmptyBody({
    this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
    this.secondaryLabel,
    this.onSecondary,
  });
  final String? title;
  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  /// 주 버튼 아래 글자 버튼
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(title!, style: AppTypography.bodyStrong.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
          ],
          Text(message, style: AppTypography.meta.copyWith(height: 1.55)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(label: actionLabel!, icon: actionIcon, variant: AppButtonVariant.white, height: 44, onPressed: onAction),
          ] else
            const SizedBox(height: AppSpacing.xs),
          if (secondaryLabel != null) Center(child: AppTextLink(label: secondaryLabel!, onPressed: onSecondary)),
        ],
      ),
    );
  }
}

/// 결과와 같은 모양의 회색 행 3개
class _RowSkeletons extends StatelessWidget {
  const _RowSkeletons();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 3; i++)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
            child: Row(
              children: [
                SkeletonBox(width: 56, height: 56, radius: 14),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 140, height: 13, radius: 5),
                      SizedBox(height: 6),
                      SkeletonBox(width: 90, height: 11, radius: 5),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
