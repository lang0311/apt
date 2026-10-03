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
import '../../my/presentation/my_providers.dart';
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
  bool? _autoAnalysis;
  MyPreferences? _initial;
  bool _saving = false;

  bool get _dirty =>
      _initial != null &&
      (_autoAnalysis != _initial!.autoAnalysisEnabled ||
          _selected!.length != _initial!.selectedKeys.length ||
          !_selected!.containsAll(_initial!.selectedKeys));

  void _init(MyPreferences mine) {
    if (_initial != null) return;
    _initial = mine;
    _selected = {...mine.selectedKeys};
    _autoAnalysis = mine.autoAnalysisEnabled;
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
      await ref.read(preferenceRepositoryProvider).save(selectedKeys: _selected!, autoAnalysisEnabled: _autoAnalysis!);
      ref.invalidate(myPreferencesProvider);
      ref.invalidate(myProfileProvider);
      // 저장한 값을 새 기준으로 — 변경 없음 상태가 되어 이탈 확인이 뜨지 않는다
      final saved = _initial!;
      _initial = MyPreferences(
        selectedKeys: {..._selected!},
        autoAnalysisSupported: saved.autoAnalysisSupported,
        autoAnalysisEnabled: _autoAnalysis!,
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
              SubPageHeader(
                title: '취향 설정',
                onBack: () => _dirty ? _confirmLeave() : _leave(),
                trailing: _selected == null
                    ? null
                    : Text('${_selected!.length}개 선택', style: AppTypography.label.copyWith(color: AppColors.textSecondary)),
              ),
              Expanded(
                child: groups.hasError || mine.hasError
                    ? AppErrorState(
                        error: (groups.error ?? mine.error)!,
                        onRetry: () {
                          ref.invalidate(preferenceGroupsProvider);
                          ref.invalidate(myPreferencesProvider);
                        },
                      )
                    : !groups.hasValue || _selected == null
                        ? const _Skeleton()
                        : _content(groups.value!, _initial!),
              ),
              BottomCta(
                child: AppButton(label: '취향 저장하기', loading: _saving, onPressed: _dirty ? _save : null),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(List<PreferenceGroup> groups, MyPreferences mine) {
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
                AppChip(
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
        // 서버가 암묵적 취향 분석을 지원할 때만 노출 (가정 A4)
        if (mine.autoAnalysisSupported) ...[
          const SizedBox(height: AppSpacing.xl),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const IconCircle(icon: Icons.bookmark_border_rounded),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('저장한 장소로 취향 자동 분석', style: AppTypography.bodyStrong),
                          if (mine.analysisBasisCount != null)
                            Text('저장한 ${mine.analysisBasisCount}곳을 바탕으로 취향을 보완해요.', style: AppTypography.caption),
                        ],
                      ),
                    ),
                    Switch(value: _autoAnalysis!, onChanged: (v) => setState(() => _autoAnalysis = v)),
                  ],
                ),
                if (_autoAnalysis! && mine.analyzedLabels.isNotEmpty) ...[
                  const Padding(padding: EdgeInsets.symmetric(vertical: AppSpacing.sm), child: Divider()),
                  Row(
                    children: [
                      Text('분석된 취향', style: AppTypography.meta),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: TagWrap(mine.analyzedLabels, tone: AppTagTone.primary)),
                    ],
                  ),
                ],
              ],
            ),
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
