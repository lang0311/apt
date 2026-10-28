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
import '../../../../core/widgets/overlays.dart';
import '../../../../core/widgets/states.dart';
import '../../../../core/widgets/surfaces.dart';
import '../../../home/presentation/home_providers.dart';
import '../../../place/domain/place.dart';
import '../../domain/course_models.dart';
import '../course_draft_controller.dart';
import '../course_providers.dart';
import '../recommendation_controller.dart';
import '../widgets/course_edit_actions.dart';
import '../widgets/course_route_map.dart';
import '../widgets/course_timeline.dart';
import '../widgets/recommending_banner.dart';

/// #30 AI 추천 (4/4) — 결과는 코스 상세와 같은 화면(머리 · 지도 · 일정 카드 "편집").
/// 장소를 누르면 시트(바꾸기 · 이번만 빼기 · 앞으로 추천하지 않기), "편집"은 상세 편집과 같은 목록.
/// 다시 추천은 내가 고른 장소를 두고 AI 자리만 바꾸고, 바뀐 자리를 주황으로 보여 준다. 진행 바는 4/4 유지.
class AiRecommendationPage extends ConsumerStatefulWidget {
  const AiRecommendationPage({super.key});

  @override
  ConsumerState<AiRecommendationPage> createState() => _AiRecommendationPageState();
}

class _AiRecommendationPageState extends ConsumerState<AiRecommendationPage> {
  bool _saving = false;
  bool _editing = false;

  RecommendationController get _rec => ref.read(recommendationProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final stale = await _rec.syncWithDraft();
      if (stale && mounted) showAppSnackBar(context, '고른 장소가 바뀌어 새로 추천받았어요');
    });
  }

  Future<void> _addPlaces() async {
    final picked = await context.push<List<Place>>(
      AppRoutes.pickPlaces,
      extra: courseAddPlacesArgs(ref.read(recommendationProvider).stops),
    );
    if (picked == null || picked.isEmpty) return;
    _rec.addPlaces(picked);
    if (mounted) showAppSnackBar(context, '${picked.length}곳을 추가했어요');
  }

  /// 처음 추천을 취소하면 장소 고르기(3/4)로 돌아간다. 고른 장소는 그대로.
  void _cancelFirst() {
    if (cancelRecommendationWithNotice(context, ref) && context.canPop()) context.pop();
  }

  Future<void> _save() async {
    final draft = ref.read(courseDraftProvider);
    final stops = ref.read(recommendationProvider).stops;
    final repo = ref.read(courseRepositoryProvider);
    setState(() => _saving = true);
    try {
      final course = await repo.createCourse(draft: draft, stops: stops);
      invalidateCourseData(ref);
      // 코스를 만들었으니 지금까지 저장한 곳은 홈 제안에서 뺀다
      ref.read(homeNudgeSeenAtProvider.notifier).markSeen();
      // 완료 화면 없이 바로 상세로 (위저드 화면은 스택에서 지워 뒤로 가면 코스 목록)
      if (mounted) context.go(AppRoutes.course(course.id, justSaved: true));
    } catch (e) {
      if (mounted) showAppSnackBar(context, failureMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recommendationProvider);
    final draft = ref.watch(courseDraftProvider);
    final busy = state.loading || _saving;

    final Widget body;
    if (!state.hasResult && state.error != null) {
      body = AppErrorState(error: state.error!, title: '추천을 받지 못했어요', onRetry: () => _rec.syncWithDraft());
    } else if (!state.hasResult) {
      body = _Waiting(
        title: draft.name,
        date: draft.date,
        stage: state.stage,
        isParty: draft.companion == Companion.party,
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.lg),
        children: [
          CourseHero(
            title: draft.name,
            meta: courseMetaLine(
              date: draft.date,
              start: draft.startTime,
              placeCount: _editing ? null : state.stops.length,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: AppSpacing.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_editing) ...[
                  CourseRouteMap(stops: state.stops, height: 160),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (_editing)
                  SectionCard(
                    title: '일정 편집',
                    child: _WithBanner(
                      show: state.loading,
                      child: CourseEditList(
                        stops: state.stops,
                        enabled: !busy,
                        addedIds: state.addedIds,
                        highlightIds: state.changedIds,
                        loadingIds: state.loadingIds,
                        onReorder: _rec.moveStop,
                        onRemove: (s) => removeStopWithUndo(context, ref, s),
                        onTapTile: (s, i) => showEditTileSheet(context, ref, s, i),
                        onAdd: _addPlaces,
                      ),
                    ),
                  )
                else
                  SectionCard(
                    title: '일정',
                    trailing: CourseEditButton(onPressed: busy ? null : () => setState(() => _editing = true)),
                    child: state.stops.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: SectionCard.innerPadding),
                            child: Text('일정에 장소가 없어요. "편집"에서 장소를 추가해 주세요.', style: AppTypography.meta),
                          )
                        : _WithBanner(
                            show: state.loading,
                            child: CourseTimeline(
                              stops: state.stops,
                              highlightIds: state.changedIds,
                              loadingIds: state.loadingIds,
                              onTapStop: busy ? null : (s) => showResultSheet(context, ref, s),
                              onMore: busy ? null : (s) => showResultSheet(context, ref, s),
                            ),
                          ),
                  ),
                if (_editing)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, AppSpacing.xs, 0, 0),
                    child: Text('시간과 이동 정보는 다시 추천하거나 완료하면 다시 계산돼요.', style: AppTypography.caption),
                  )
                else if (!state.stops.any((s) => s.isAi))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, AppSpacing.xs, 0, 0),
                    // 추천 0건 — 디자인 없음 (docs/07 §3)
                    child: Text('지금 조건에 맞는 추천 장소를 찾지 못했어요. 장소나 분위기를 바꿔 다시 추천받아 보세요.', style: AppTypography.caption),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    return PopScope(
      canPop: !_editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _editing) setState(() => _editing = false);
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              StepHeader(step: 4, onBack: _editing ? () => setState(() => _editing = false) : null),
              Expanded(child: body),
              if (state.hasResult)
                BottomCta(
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: AppButton(
                          label: '다시 추천',
                          variant: AppButtonVariant.white,
                          loading: state.loading,
                          onPressed: busy ? null : () => recommendAgainWithUndo(context, ref),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        flex: 3,
                        child: _editing
                            ? AppButton(label: '완료', onPressed: busy ? null : () => setState(() => _editing = false))
                            : AppButton(
                                label: '코스 저장',
                                loading: _saving,
                                onPressed: busy || state.stops.isEmpty ? null : _save,
                              ),
                      ),
                    ],
                  ),
                )
              else if (state.loading)
                BottomCta(
                  child: AppButton(label: '추천 취소', variant: AppButtonVariant.white, onPressed: _cancelFirst),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 다시 추천하는 동안 일정 위에 진행 줄(+ 취소)을 붙인다
class _WithBanner extends ConsumerWidget {
  const _WithBanner({required this.show, required this.child});
  final bool show;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!show) return child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RecommendingBanner(onCancel: () => cancelRecommendationWithNotice(context, ref)),
        child,
      ],
    );
  }
}

/// 기다리는 동안: 결과와 같은 자리에 뼈대(제목 → 지도 자리의 단계 표시 → 일정)
class _Waiting extends StatelessWidget {
  const _Waiting({required this.title, required this.date, required this.stage, required this.isParty});
  final String title;
  final DateTime? date;
  final RecommendationStage? stage;
  final bool isParty;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.lg),
      children: [
        CourseHero(title: '코스를 만들고 있어요', meta: [title, if (date != null) formatMonthDayWeekday(date!)].join(' · ')),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: _Stages(stage: stage ?? RecommendationStage.findCandidates, isParty: isParty),
              ),
              const SizedBox(height: AppSpacing.sm),
              SectionCard(
                title: '일정',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: Column(
                    children: [
                      for (final w in const [0.6, 0.5, 0.65]) ...[
                        Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                          decoration: BoxDecoration(color: AppColors.surfaceRaised, borderRadius: BorderRadius.circular(14)),
                          child: Row(
                            children: [
                              const SkeletonBox(width: 26, height: 26, radius: 13),
                              const SizedBox(width: 10),
                              Expanded(child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: w, child: const SkeletonBox(height: 11, radius: 5))),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 단계 표시 — 서버가 알려 주는 진행 단계(묶음). 파티 코스만 '파티원 취향 맞추기'를 거친다.
class _Stages extends StatelessWidget {
  const _Stages({required this.stage, required this.isParty});
  final RecommendationStage stage;
  final bool isParty;

  static const _labels = {
    RecommendationStage.findCandidates: '후보 장소 찾기',
    RecommendationStage.checkPlaces: '장소 정보 확인',
    RecommendationStage.matchTaste: '파티원 취향 맞추기',
    RecommendationStage.organize: '동선 정리',
  };

  /// 끝난 단계 = 체크, 지금 단계 = 진행 원, 남은 단계 = 빈 원
  Widget _icon(RecommendationStage s) {
    if (s.index < stage.index) {
      return Container(
        decoration: const BoxDecoration(color: AppColors.successSoft, shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, size: 14, color: AppColors.success),
      );
    }
    if (s == stage) return const CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary);
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.progressInactive, width: 2),
      ),
    );
  }

  Color _textColor(RecommendationStage s) {
    if (s == stage) return AppColors.textPrimary;
    if (s.index < stage.index) return AppColors.textSecondary;
    return AppColors.textTertiary;
  }

  @override
  Widget build(BuildContext context) {
    final stages = [
      for (final s in RecommendationStage.values)
        if (isParty || s != RecommendationStage.matchTaste) s,
    ];
    return Semantics(
      liveRegion: true,
      label: '${_labels[stage]} 중',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final s in stages)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox.square(dimension: 20, child: _icon(s)),
                  const SizedBox(width: 10),
                  Text(
                    _labels[s]!,
                    style: AppTypography.bodyStrong.copyWith(
                      color: _textColor(s),
                      fontWeight: s == stage ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
