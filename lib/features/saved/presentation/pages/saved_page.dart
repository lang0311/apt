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
import '../widgets/create_collection_modal.dart';
import '../widgets/saved_rows.dart';

/// #13 / #14 저장됨 — [카테고리 | 내 보관함] (2026-10-20 개편, docs/05 #13·#14, 07 D21)
/// 카테고리 탭은 평소엔 '전체 n곳 · 필터'만 두고, 필터를 걸었을 때만 칩 하나로 조건을 보여 준다.
/// 목록은 홈과 같은 SectionCard 하나 안의 구분선 행이다. 지도는 상단바 버튼 하나로만 연다.
class SavedPage extends ConsumerStatefulWidget {
  const SavedPage({super.key});

  @override
  ConsumerState<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends ConsumerState<SavedPage> {
  int _tab = 0;

  /// 섹션 묶음 바깥 여백 (홈과 같은 값)
  static const _outer = AppSpacing.sm;

  Future<void> _createCollection() async {
    final created = await showCreateCollectionModal(context);
    if (created != null && mounted) context.push(AppRoutes.collection(created.id));
  }

  Future<void> _refresh() async {
    invalidateSavedData(ref);
    await ref.read(savedSummaryProvider.future).catchError((_) => const SavedSummary(totalCount: 0, categories: []));
  }

  void _openMap() {
    final category = ref.read(savedCategoryFilterProvider);
    context.push(_tab == 0 ? AppRoutes.categoryMap(categoryKey: category) : AppRoutes.collectionMap());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
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
                  labels: const ['카테고리', '내 보관함'],
                  selectedIndex: _tab,
                  style: SegmentedStyle.underline,
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: _outer),
                child: _tab == 0
                    ? const _CategoryTab()
                    : _CollectionsTab(
                        onCreate: _createCollection,
                        onShowAll: () {
                          ref.read(savedCategoryFilterProvider.notifier).select(null);
                          setState(() => _tab = 0);
                        },
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
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
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
    final title = summary == null
        ? '저장한 곳'
        : selected == null
            ? '전체 ${summary.totalCount}곳'
            : '${selected.label} ${selected.count}곳';

    return SectionCard(
      title: title,
      trailing: summary == null || (!filterable && selected == null)
          ? null
          : HeaderTextButton(
              label: '필터',
              icon: Icons.tune_rounded,
              active: selected != null,
              semanticLabel: selected == null ? '카테고리 필터' : '카테고리 필터, ${selected.label} 적용됨',
              onPressed: () async {
                final pick = await showCategoryFilterSheet(context, summary: summary, selectedKey: selectedKey);
                if (pick != null) ref.read(savedCategoryFilterProvider.notifier).select(pick.key);
              },
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (selected != null)
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
              children: [
                for (final item in list)
                  SavedPlaceRow(place: item.place, onTap: () => context.push(AppRoutes.place(item.place.id))),
              ],
            ),
          ),
        ],
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
                for (final c in list)
                  CollectionRow(
                    collection: c,
                    onTap: () => context.push(AppRoutes.collection(c.id)),
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

/// 컨테이너 안 빈 상태: (제목) + 한두 문장 + 버튼 하나
class _EmptyBody extends StatelessWidget {
  const _EmptyBody({
    this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.actionIcon,
    this.secondaryLabel,
    this.onSecondary,
  });
  final String? title;
  final String message;
  final String actionLabel;
  final IconData? actionIcon;
  final VoidCallback onAction;

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
          const SizedBox(height: AppSpacing.sm),
          AppButton(label: actionLabel, icon: actionIcon, variant: AppButtonVariant.white, height: 44, onPressed: onAction),
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
