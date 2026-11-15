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
import '../../../course/domain/course_models.dart';
import '../../../course/presentation/widgets/course_thumb.dart';
import '../../domain/saved_models.dart';
import '../saved_providers.dart';
import '../saved_selection.dart';
import '../widgets/create_collection_modal.dart';
import '../widgets/saved_rows.dart';

/// #13 / #14 저장됨 — [전체 | 보관함 | AI 추천] (2026-10-20 개편, 11-14 지역 묶음, docs/05 #13·#14, 07 D21 · D44 · D45)
/// 전체 탭은 보기 방식(지역별 · 업종별 · 최근 저장한 순 · 이름순)으로 묶고, 필터는 지역별이면 지역, 그 밖에는 업종을 고른다.
/// 칩 줄에는 보기 방식 · 필터 · 고른 값만 올라온다.
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
    return awaitRefresh(context, [
      ref.read(savedSummaryProvider.future),
      if (_tab == 0) ref.read(savedPlacesProvider(const SavedPlaceQuery()).future),
      if (_tab == 1) ref.read(collectionsProvider.future),
      if (_tab == 2) ref.read(aiSavedPlacesProvider.future),
    ]);
  }

  /// '지도': 카테고리 탭은 고른 카테고리 그대로, AI 추천 탭은 추천받은 곳만 켜진 저장 지도 (07 D48)
  void _openMap() {
    context.push(switch (_tab) {
      1 => AppRoutes.collectionMap(),
      2 => AppRoutes.categoryMap(categoryKeys: ref.read(aiCategoryFilterProvider), aiOnly: true),
      _ => AppRoutes.categoryMap(categoryKeys: ref.read(savedCategoryFilterProvider)),
    });
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
                          labels: const ['전체', '보관함', 'AI 추천'],
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
                              ref.read(savedCategoryFilterProvider.notifier).clear();
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
                  child: AppButton(
                    variant: AppButtonVariant.danger,
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

  static const _noArea = '동네 정보 없음';

  static String _regionOf(SavedPlaceItem i) {
    final d = i.place.district;
    return d.isEmpty ? _noArea : d;
  }

  /// 동네(동 · 읍 · 면). 지역 이름과 같으면(동이 없는 주소) 동네 정보 없음
  static String _dongOf(SavedPlaceItem i) {
    final a = i.place.shortArea;
    return a.isEmpty || a == i.place.district ? _noArea : a;
  }

  /// 지역 필터 값은 '마포구' 또는 동네까지 '마포구 연남동' (동네 줄을 눌렀을 때, 07 D59)
  static bool _inRegions(SavedPlaceItem i, Set<String> regions) =>
      regions.isEmpty || regions.contains(_regionOf(i)) || regions.contains('${_regionOf(i)} ${_dongOf(i)}');

  /// 지역 필터 시트용 요약: 지역마다 곳 수 (많은 순, 동네 정보 없음은 맨 아래)
  static SavedSummary _regionSummary(List<SavedPlaceItem> all) {
    final counts = <String, int>{};
    for (final i in all) {
      counts.update(_regionOf(i), (n) => n + 1, ifAbsent: () => 1);
    }
    final keys = counts.keys.toList()
      ..sort((a, b) => a == _noArea ? 1 : b == _noArea ? -1 : counts[b]!.compareTo(counts[a]!));
    return SavedSummary(totalCount: all.length, categories: [for (final k in keys) PlaceCategory(key: k, label: k, count: counts[k]!)]);
  }

  Future<void> _pickView(BuildContext context, WidgetRef ref, SavedView current) async {
    final picked = await showAppBottomSheet<SavedView>(
      context,
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xxs, AppSpacing.lg, AppSpacing.xs),
              child: Text('어떻게 볼까요?', style: AppTypography.section),
            ),
            for (final v in SavedView.values)
              Semantics(
                selected: v == current,
                button: true,
                child: InkWell(
                  onTap: () => Navigator.of(ctx).pop(v),
                  child: SizedBox(
                    height: 52,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              v.label,
                              style: AppTypography.bodyStrong.copyWith(
                                color: v == current ? AppColors.primary : AppColors.textPrimary,
                                fontWeight: v == current ? FontWeight.w800 : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (v == current) const Icon(Icons.check_rounded, color: AppColors.primary, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.md),
              child: Text('지역별이면 필터에서 지역을, 그 밖에는 업종을 골라요.', style: AppTypography.caption),
            ),
          ],
        ),
      ),
    );
    if (picked == null || picked == current) return;
    // 보기 방식이 바뀌면 필터 종류가 바뀌니 고른 값을 푼다
    ref.read(savedCategoryFilterProvider.notifier).clear();
    ref.read(savedRegionFilterProvider.notifier).clear();
    ref.read(savedViewProvider.notifier).set(picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryValue = ref.watch(savedSummaryProvider);
    final summary = summaryValue.value;
    final view = ref.watch(savedViewProvider);
    final byRegion = view == SavedView.region;
    // 지운 뒤 사라진 카테고리는 빼고 본다 (모두 사라지면 전체)
    final keys = byRegion ? const <String>{} : _liveKeys(summary, ref.watch(savedCategoryFilterProvider));
    final regions = byRegion ? ref.watch(savedRegionFilterProvider) : const <String>{};
    final allValue = ref.watch(savedPlacesProvider(const SavedPlaceQuery()));
    final all = allValue.value ?? const <SavedPlaceItem>[];
    final places = allValue.whenData(
      (list) => [
        for (final item in list)
          if (matchesCategories(item.place, keys) && _inRegions(item, regions)) item,
      ],
    );
    final regionSummary = _regionSummary(all);
    final applied = byRegion ? regions : keys;
    final selected = applied.isNotEmpty;
    void clear() => byRegion ? ref.read(savedRegionFilterProvider.notifier).clear() : ref.read(savedCategoryFilterProvider.notifier).clear();

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

    final selection = ref.watch(savedSelectionProvider);
    final visible = places.value ?? const <SavedPlaceItem>[];
    final title = summary == null ? '저장한 곳' : selected ? '${visible.length}곳' : '전체 ${summary.totalCount}곳';
    final filterSummary = byRegion ? regionSummary : summary;
    final showFilter = filterSummary != null && (filterSummary.categories.where((c) => c.count > 0).length > 1 || selected);

    Future<void> openFilter() => showCategoryFilterSheet(
          context,
          summary: filterSummary!,
          selected: applied,
          title: byRegion ? '지역' : '카테고리',
          // 지역은 줄마다 같은 핀이라 아이콘 칸 없이 이름 · 개수만
          styleOf: byRegion ? (_) => null : null,
          onApply: (picked) => byRegion
              ? ref.read(savedRegionFilterProvider.notifier).select(picked)
              : ref.read(savedCategoryFilterProvider.notifier).select(picked),
        );

    return SectionCard(
      title: selection.active ? '전체 선택' : title,
      titleWidget: selection.active ? _SelectAllTitle(items: visible) : null,
      trailing: selection.active ? const _DoneButton() : visible.isEmpty ? null : const _SelectButton(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 칩 줄: 보기 방식 · 필터 · 고른 값만 (고르기 전에는 지역 · 업종 이름을 늘어놓지 않는다)
          if (!selection.active)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xs),
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  _ToolChip(label: view.label, trailingIcon: Icons.expand_more_rounded, onTap: () => _pickView(context, ref, view)),
                  if (showFilter)
                    _ToolChip(
                      label: '필터',
                      leadingIcon: Icons.tune_rounded,
                      count: applied.length,
                      semanticLabel: selected ? '${byRegion ? '지역' : '카테고리'} 필터, ${applied.length}개 적용됨' : '${byRegion ? '지역' : '카테고리'} 필터',
                      onTap: openFilter,
                    ),
                  for (final k in applied)
                    AppliedFilterChip(
                      label: byRegion ? k : (summary?.categories.where((c) => c.key == k).firstOrNull?.label ?? k),
                      onClear: () {
                        final rest = {...applied}..remove(k);
                        byRegion
                            ? ref.read(savedRegionFilterProvider.notifier).select(rest)
                            : ref.read(savedCategoryFilterProvider.notifier).select(rest);
                      },
                    ),
                ],
              ),
            ),
          AsyncValueView(
            value: places,
            compactError: true,
            onRetry: () => ref.invalidate(savedPlacesProvider),
            loading: const _RowSkeletons(),
            isEmpty: (list) => list.isEmpty,
            empty: _EmptyBody(
              title: selected ? '고른 조건에 저장한 곳이 없어요' : null,
              message: '다른 조건을 고르거나 전체로 돌아가 보세요.',
              actionLabel: '전체 보기',
              onAction: clear,
            ),
            data: (list) => _GroupedRows(
              items: list,
              view: view,
              indent: selection.active ? 116 : 88,
              // 동네 줄을 누르면 그 동네로 거른다 (칩 '마포구 연남동', ×로 풂)
              onOpenDong: selection.active ? null : (key) => ref.read(savedRegionFilterProvider.notifier).select({key}),
            ),
          ),
        ],
      ),
    );
  }
}

/// 보기 방식대로 묶거나 정렬한 행. 지역별 · 업종별은 묶음 제목(이름 · n곳)을 달고 곳 수가 많은 묶음부터,
/// 묶음이 여섯 곳을 넘으면 세 곳만 보이고 '모두 보기'로 펼친다.
/// 지역별에서 한 지역이 스무 곳을 넘으면 장소 대신 동네 줄(모자이크 · 연남동 9곳 · 장소 이름)로 나눈다(07 D59).
class _GroupedRows extends StatefulWidget {
  const _GroupedRows({required this.items, required this.view, required this.indent, this.onOpenDong});
  final List<SavedPlaceItem> items;
  final SavedView view;
  final double indent;

  /// 동네 줄을 눌렀을 때 ('마포구 연남동'). 없으면(선택 중) 동네로 나누지 않는다
  final ValueChanged<String>? onOpenDong;

  @override
  State<_GroupedRows> createState() => _GroupedRowsState();
}

class _GroupedRowsState extends State<_GroupedRows> {
  final _open = <String>{};
  static const _preview = 3;
  static const _foldOver = 6;
  static const _splitOver = 20;

  /// 한 지역의 장소를 동네로 묶는다 (곳 수가 많은 동네부터, 동네 정보 없음은 맨 끝)
  List<MapEntry<String, List<SavedPlaceItem>>> _dongs(List<SavedPlaceItem> items) {
    final map = <String, List<SavedPlaceItem>>{};
    for (final i in items) {
      map.putIfAbsent(_CategoryTab._dongOf(i), () => []).add(i);
    }
    return map.entries.toList()
      ..sort((a, b) => a.key == _CategoryTab._noArea ? 1 : b.key == _CategoryTab._noArea ? -1 : b.value.length.compareTo(a.value.length));
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    switch (widget.view) {
      case SavedView.recent:
        return DividedRows(indent: widget.indent, children: [for (final i in items) _SavedRow(item: i)]);
      case SavedView.name:
        final sorted = [...items]..sort((a, b) => a.place.name.compareTo(b.place.name));
        return DividedRows(indent: widget.indent, children: [for (final i in sorted) _SavedRow(item: i)]);
      case SavedView.region:
      case SavedView.category:
        final byRegion = widget.view == SavedView.region;
        final map = <String, List<SavedPlaceItem>>{};
        for (final i in items) {
          final key = byRegion ? _CategoryTab._regionOf(i) : i.place.categoryLabel;
          map.putIfAbsent(key, () => []).add(i);
        }
        final groups = map.entries.toList()
          ..sort((a, b) => a.key == _CategoryTab._noArea ? 1 : b.key == _CategoryTab._noArea ? -1 : b.value.length.compareTo(a.value.length));
        // 묶음이 하나면 제목 없이 목록만
        if (groups.length == 1) {
          return DividedRows(indent: widget.indent, children: [for (final i in items) _SavedRow(item: i)]);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (gi, g) in groups.indexed) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(AppSpacing.md, gi == 0 ? AppSpacing.xxs : AppSpacing.md, AppSpacing.md, 0),
                child: Row(
                  children: [
                    Expanded(child: Text(g.key, style: AppTypography.label)),
                    Text('${g.value.length}곳', style: AppTypography.meta),
                  ],
                ),
              ),
              if (byRegion && widget.onOpenDong != null && g.key != _CategoryTab._noArea && g.value.length > _splitOver)
                DividedRows(
                  indent: SectionCard.innerPadding + 44 + AppSpacing.sm,
                  children: [
                    for (final d in _dongs(g.value))
                      _DongRow(
                        name: d.key,
                        items: d.value,
                        onTap: () => widget.onOpenDong!(d.key == _CategoryTab._noArea ? g.key : '${g.key} ${d.key}'),
                      ),
                  ],
                )
              else ...[
              DividedRows(
                indent: widget.indent,
                children: [
                  for (final i in (g.value.length > _foldOver && !_open.contains(g.key)) ? g.value.take(_preview) : g.value) _SavedRow(item: i),
                ],
              ),
              if (g.value.length > _foldOver && !_open.contains(g.key))
                InkWell(
                  onTap: () => setState(() => _open.add(g.key)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.sm, AppSpacing.xs),
                    child: Row(
                      children: [
                        Expanded(child: Text('${g.key} ${g.value.length}곳 모두 보기', style: AppTypography.label.copyWith(color: AppColors.primary))),
                        const Icon(Icons.expand_more_rounded, color: AppColors.primary, size: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        );
    }
  }
}

/// 동네 줄: 업종 모자이크 · '연남동 9곳' · 장소 이름 셋 · ›
class _DongRow extends StatelessWidget {
  const _DongRow({required this.name, required this.items, required this.onTap});
  final String name;
  final List<SavedPlaceItem> items;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(SectionCard.innerPadding, 10, AppSpacing.sm, 10),
        child: Row(
          children: [
            CourseThumb(
              course: CourseSummary(id: name, title: name, placeCount: items.length, stopCategoryKeys: [for (final i in items) i.place.categoryKey]),
              size: 44,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$name ${items.length}곳', style: AppTypography.bodyStrong),
                  Text(items.take(3).map((i) => i.place.name).join(', '), style: AppTypography.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// 칩 줄의 도구 칩 (보기 방식 ▾ · 필터). 흰 바탕 + 테두리, 필터를 걸면 숫자 배지
class _ToolChip extends StatelessWidget {
  const _ToolChip({required this.label, required this.onTap, this.leadingIcon, this.trailingIcon, this.count = 0, this.semanticLabel});
  final String label;
  final VoidCallback onTap;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final int count;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: Material(
        color: AppColors.surfaceRaised,
        shape: StadiumBorder(side: BorderSide(color: count > 0 ? AppColors.primary : AppColors.border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 34),
            child: Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.sm, 0, trailingIcon == null ? AppSpacing.sm : 6, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leadingIcon != null) ...[Icon(leadingIcon, size: 15, color: AppColors.textPrimary), const SizedBox(width: 4)],
                  Text(label, style: AppTypography.label.copyWith(fontSize: 13)),
                  if (count > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(AppRadius.small)),
                      child: Text('$count', style: AppTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1)),
                    ),
                  ],
                  if (trailingIcon != null) ...[const SizedBox(width: 2), Icon(trailingIcon, size: 18, color: AppColors.textSecondary)],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 고른 카테고리 중 아직 요약에 있는 것만 (지운 뒤 사라진 카테고리는 뺀다). 요약을 아직 모르면 그대로
Set<String> _liveKeys(SavedSummary? summary, Set<String> keys) =>
    summary == null ? keys : {for (final k in keys) if (summary.categories.any((c) => c.key == k)) k};

/// AI 추천 탭: 코스를 저장할 때 AI 추천으로 저장 목록에 들어온 장소 (07 D44).
/// 카테고리 탭과 같은 '전체 n곳 · 필터 · 선택' 줄을 두고, 필터는 이 탭의 장소 기준으로 센다 (07 D47).
class _AiTab extends ConsumerWidget {
  const _AiTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final places = ref.watch(aiSavedPlacesProvider);
    final summary = ref.watch(aiSavedSummaryProvider).value;
    final selection = ref.watch(savedSelectionProvider);
    final all = places.value;
    // 지운 뒤 사라진 카테고리는 빼고 본다 (모두 사라지면 전체)
    final keys = _liveKeys(summary, ref.watch(aiCategoryFilterProvider));
    final label = categoryFilterLabel(summary, keys);
    final selected = keys.isNotEmpty;
    void clear() => ref.read(aiCategoryFilterProvider.notifier).clear();
    final visible = [
      for (final item in all ?? const <SavedPlaceItem>[])
        if (matchesCategories(item.place, keys)) item,
    ];
    final filterable = summary != null && summary.categories.where((c) => c.count > 0).length > 1;
    final showFilter = summary != null && (filterable || selected);
    final String title;
    if (all == null) {
      title = 'AI 추천';
    } else if (!selected) {
      title = '전체 ${all.length}곳';
    } else {
      title = '$label ${visible.length}곳';
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
                        active: selected,
                        semanticLabel: selected ? '카테고리 필터, $label 적용됨' : '카테고리 필터',
                        onPressed: () => showCategoryFilterSheet(
                          context,
                          summary: summary,
                          selected: keys,
                          onApply: (picked) => ref.read(aiCategoryFilterProvider.notifier).select(picked),
                        ),
                      ),
                    if (visible.isNotEmpty) const _SelectButton(),
                  ],
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (selected && !selection.active)
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xxs),
                  child: Align(alignment: Alignment.centerLeft, child: AppliedFilterChip(label: label, onClear: clear)),
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
        borderRadius: BorderRadius.circular(AppRadius.small),
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
