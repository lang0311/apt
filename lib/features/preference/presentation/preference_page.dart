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
      _initial = MyPreferences(
        selectedKeys: {..._selected!},
        autoAnalysisSupported: saved.autoAnalysisSupported,
        autoAnalysisEnabled: saved.autoAnalysisEnabled,
        analyzedLabels: saved.analyzedLabels,
        analysisBasisCount: saved.analysisBasisCount,
      );
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
                title: '취향 설정',
                onLeading: () => _dirty ? _confirmLeave() : _leave(),
                trailing: _selected == null
                    ? null
                    : Text('${_selected!.length}개 선택', style: AppTypography.label.copyWith(color: AppColors.textSecondary)),
              ),
              Expanded(child: _body(groups, mine)),
              BottomCta(
                child: AppButton(label: '취향 저장하기', loading: _saving, onPressed: _dirty ? _save : null),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(AsyncValue<List<PreferenceGroup>> groups, AsyncValue<MyPreferences> mine) {
    if (groups.hasError || mine.hasError) {
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
