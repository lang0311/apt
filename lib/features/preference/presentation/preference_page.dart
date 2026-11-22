import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di/repositories.dart';
import '../../../app/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/config/feature_flags.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/widgets/bottom_cta.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/widgets/headers.dart';
import '../../../core/widgets/overlays.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/surfaces.dart';
import '../../saved/domain/saved_models.dart';
import '../../saved/presentation/saved_providers.dart';
import '../../saved/presentation/widgets/category_style.dart';
import '../domain/preference_models.dart';
import 'preference_providers.dart';

/// #34 취향 설정. 칩 그룹/항목은 서버 키워드 체계로 동적 렌더링한다 (시안 항목은 예시).
/// [onboarding]: 가입 중 진입 — 저장 후 프로필 설정으로 복귀.
class PreferencePage extends ConsumerStatefulWidget {
  const PreferencePage({super.key, this.onboarding = false});
  final bool onboarding;

  @override
  ConsumerState<PreferencePage> createState() => _PreferencePageState();
}

class _PreferencePageState extends ConsumerState<PreferencePage> {
  Set<String>? _selected;

  /// 마지막으로 서버에 저장된 값 (변경 여부 비교 기준)
  MyPreferences? _initial;
  bool _saving = false;

  bool get _dirty => _initial != null && (_selected!.length != _initial!.selectedKeys.length || !_selected!.containsAll(_initial!.selectedKeys));

  void _init(MyPreferences mine) {
    if (_initial != null) return;
    _initial = mine;
    _selected = {...mine.selectedKeys};
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(widget.onboarding ? AppRoutes.signupProfile : AppRoutes.my);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final saved = _initial!;
      // 자동 분석은 화면에 없는 기능 (07 §3) — 서버에서 받은 값을 그대로 다시 보낸다
      await ref.read(preferenceRepositoryProvider).save(selectedKeys: _selected!, autoAnalysisEnabled: saved.autoAnalysisEnabled);
      ref.invalidate(myPreferencesProvider);
      // 저장한 값을 새 기준으로 — 변경 없음 상태가 되어 이탈 확인이 뜨지 않는다
      _initial = MyPreferences(selectedKeys: {..._selected!}, autoAnalysisEnabled: saved.autoAnalysisEnabled);
      if (!mounted) return;
      if (!widget.onboarding) showAppSnackBar(context, '취향을 저장했어요.');
      _leave();
    } catch (e) {
      if (mounted) showAppSnackBar(context, failureMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmLeave() async {
    final leave = await showConfirmDialog(context, title: '변경 사항을 저장하지 않을까요?', message: '선택한 취향이 저장되지 않아요.', confirmLabel: '나가기', cancelLabel: '계속 편집');
    if (leave && mounted) _leave();
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(preferenceGroupsProvider);
    final mine = ref.watch(myPreferencesProvider);
    if (mine.hasValue) _init(mine.value!);
    // 서버에 직접 고르는 취향 항목이 없으면(팀 서버, NEEDS BACKEND) 고르는 화면 대신 설명 화면
    // v2: 직접 고르는 취향은 플래그가 켜졌을 때만 (지금은 꺼 둠, 2026-11-21)
    final manual = FeatureFlags.manualTasteEnabled && !(groups.hasValue && groups.value!.isEmpty);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              PlainHeader(
                // v2: 저장한 장소로 읽는 화면은 큰 제목이 본문에 있다
                title: manual ? '취향 설정' : null,
                onLeading: () => _dirty ? _confirmLeave() : _leave(),
                trailing: _selected == null || !manual
                    ? null
                    : Text('${_selected!.length}개 선택', style: AppTypography.label.copyWith(color: AppColors.textSecondary)),
              ),
              Expanded(child: manual ? _body(groups, mine) : const _AutoTaste()),
              BottomCta(
                child: manual
                    ? AppButton(label: '취향 저장하기', loading: _saving, onPressed: _dirty ? _save : null)
                    : widget.onboarding
                    ? AppButton(label: '다음', onPressed: _leave)
                    : AppButton(label: '장소 더 저장하기', onPressed: () => context.go(AppRoutes.extract)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(AsyncValue<List<PreferenceGroup>> groups, AsyncValue<MyPreferences> mine) {
    if ((groups.hasError && !groups.hasValue) || (mine.hasError && !mine.hasValue)) {
      return AppErrorState(
        error: (groups.error ?? mine.error)!,
        onRetry: () {
          ref.invalidate(preferenceGroupsProvider);
          ref.invalidate(myPreferencesProvider);
        },
      );
    }
    if (!groups.hasValue || _selected == null) return const _Skeleton();
    return _content(groups.value!);
  }

  Widget _content(List<PreferenceGroup> groups) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, AppSpacing.lg),
      children: [
        Text('어떤 곳을 좋아하세요?', style: AppTypography.title),
        const SizedBox(height: 4),
        Text('선택한 취향은 AI 추천과 파티 코스에 반영돼요.', style: AppTypography.bodyMuted),
        for (final g in groups) ...[
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(child: Text(g.label, style: AppTypography.label)),
              Text(g.multiSelect ? '복수 선택' : '하나 선택', style: AppTypography.caption),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final item in g.items)
                AppTextChip(
                  label: item.label,
                  selected: _selected!.contains(item.key),
                  onTap: () => setState(() {
                    if (_selected!.contains(item.key)) {
                      _selected!.remove(item.key);
                    } else {
                      if (!g.multiSelect) _selected!.removeAll(g.items.map((i) => i.key));
                      _selected!.add(item.key);
                    }
                  }),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// 직접 고르는 취향이 없을 때(v2 "34 내 취향"): 추천이 무엇을 보고 만들어지는지 설명하고, 저장한 곳의 업종별 수와
/// 추천하지 않는 장소로 가는 길을 둔다. 직접 고르는 취향은 [FeatureFlags.manualTasteEnabled]가 켜질 때만.
class _AutoTaste extends ConsumerWidget {
  const _AutoTaste();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(savedSummaryProvider);
    final top = [...?summary.value?.categories.where((c) => c.count > 0)]..sort((a, b) => b.count.compareTo(a.count));
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      children: [
        Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text('내 취향', style: AppTypography.display)),
              const SizedBox(height: 6),
              // v2: 회색 한 문단
              Text('저장한 장소로 취향을 읽어요. 따로 고르지 않아도 많이 저장할수록 추천이 잘 맞아요.', style: AppTypography.bodyMuted),
            ],
          ),
        ),
        if (top.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
            child: SectionCard(
              title: '직접 저장한 곳',
              trailing: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Text('${summary.value!.totalCount}곳', style: AppTypography.meta),
              ),
              child: Column(children: [for (final c in top.take(5)) _CategoryRow(category: c)]),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        const SectionGap(),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.lg, AppSpacing.screenH, AppSpacing.xxs),
          child: Semantics(header: true, child: Text('추천에서 빼고 싶다면', style: AppTypography.cardTitle)),
        ),
        Semantics(
          button: true,
          label: '추천하지 않는 장소',
          excludeSemantics: true,
          child: InkWell(
            onTap: () => context.push(AppRoutes.blockedPlaces),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xs, AppSpacing.md, AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(child: Text('추천하지 않는 장소', style: AppTypography.body)),
                    const Icon(LucideIcons.chevronRight, color: AppColors.textHint),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 업종 한 줄: 업종 색 칸 36 · 이름 · n곳 (서버 요약 값)
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category});
  final PlaceCategory category;

  @override
  Widget build(BuildContext context) {
    final style = CategoryStyle.of(category.key);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 58),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SectionCard.innerPadding, vertical: AppSpacing.xxs),
        child: Row(
          children: [
            CategoryColorTile(style: style, width: 36, height: 36, radius: AppRadius.small, iconSize: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(category.label, style: AppTypography.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Text('${category.count}곳', style: AppTypography.bodyStrong.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.screenPadding,
      children: const [
        SizedBox(height: AppSpacing.md),
        SkeletonBox(width: 200, height: 24),
        SizedBox(height: AppSpacing.xl),
        SkeletonBox(height: 80),
        SizedBox(height: AppSpacing.lg),
        SkeletonBox(height: 80),
        SizedBox(height: AppSpacing.lg),
        SkeletonBox(height: 80),
      ],
    );
  }
}
