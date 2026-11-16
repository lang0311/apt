import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di/repositories.dart';
import '../../../app/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/widgets/bottom_cta.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/widgets/headers.dart';
import '../../../core/widgets/overlays.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/surfaces.dart';
import '../../saved/presentation/saved_providers.dart';
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

  bool get _dirty =>
      _initial != null &&
      (_selected!.length != _initial!.selectedKeys.length || !_selected!.containsAll(_initial!.selectedKeys));

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
    final leave = await showConfirmDialog(
      context,
      title: '변경 사항을 저장하지 않을까요?',
      message: '선택한 취향이 저장되지 않아요.',
      confirmLabel: '나가기',
      cancelLabel: '계속 편집',
    );
    if (leave && mounted) _leave();
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(preferenceGroupsProvider);
    final mine = ref.watch(myPreferencesProvider);
    if (mine.hasValue) _init(mine.value!);
    // 서버에 직접 고르는 취향 항목이 없으면(팀 서버, NEEDS BACKEND) 고르는 화면 대신 설명 화면
    final manual = !(groups.hasValue && groups.value!.isEmpty);

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
                title: manual ? '취향 설정' : '취향',
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
        Text('선택한 취향은 AI 추천과 파티 코스에 반영돼요.', style: AppTypography.body),
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

/// 직접 고르는 취향이 없을 때: 추천이 무엇을 보고 만들어지는지 설명하고, 저장한 곳의 업종별 수와
/// 추천하지 않는 장소로 가는 길을 둔다. 서버에 취향 항목이 생기면 고르는 화면으로 돌아간다.
class _AutoTaste extends ConsumerWidget {
  const _AutoTaste();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(savedSummaryProvider);
    final top = [...?summary.value?.categories.where((c) => c.count > 0)]..sort((a, b) => b.count.compareTo(a.count));
    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.lg),
      children: [
        Padding(
          padding: AppSpacing.screenPadding,
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('저장한 장소로 취향을 읽어요', style: AppTypography.cardTitle),
                const SizedBox(height: 6),
                Text('지금은 취향을 직접 고르지 않아도 돼요. 저장한 장소가 늘수록 추천이 더 잘 맞아요.', style: AppTypography.body),
              ],
            ),
          ),
        ),
        if (top.isNotEmpty) ...[
          SectionHeader(
            title: '직접 저장한 곳',
            trailingText: '${summary.value!.totalCount}곳',
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.lg, AppSpacing.screenH, AppSpacing.xs),
          ),
          Padding(
            padding: AppSpacing.screenPadding,
            child: AppCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
              child: DividedRows(
                indent: SectionCard.innerPadding,
                children: [
                  for (final c in top.take(5))
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: SectionCard.innerPadding, vertical: AppSpacing.sm),
                      child: Row(
                        children: [
                          Expanded(child: Text(c.label, style: AppTypography.bodyStrong)),
                          Text('${c.count}곳', style: AppTypography.meta),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
        const SectionHeader(
          title: '추천에서 빼고 싶다면',
          padding: EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.lg, AppSpacing.screenH, AppSpacing.xs),
        ),
        Padding(
          padding: AppSpacing.screenPadding,
          child: AppCard(
            onTap: () => context.push(AppRoutes.blockedPlaces),
            child: Row(
              children: [
                Expanded(child: Text('추천하지 않는 장소', style: AppTypography.bodyStrong)),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
              ],
            ),
          ),
        ),
      ],
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
