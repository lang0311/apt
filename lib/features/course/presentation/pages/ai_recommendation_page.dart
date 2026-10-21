import 'dart:async';

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
import '../course_draft_controller.dart';
import '../course_providers.dart';
import '../recommendation_controller.dart';
import '../widgets/course_edit_actions.dart';
import '../widgets/course_route_map.dart';
import '../widgets/course_timeline.dart';

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

  Future<void> _save() async {
    final draft = ref.read(courseDraftProvider);
    final stops = ref.read(recommendationProvider).stops;
    final repo = ref.read(courseRepositoryProvider);
    setState(() => _saving = true);
    try {
      if (draft.isEditingExisting) {
        await repo.updateCourseStops(courseId: draft.courseId!, stops: stops);
        invalidateCourseData(ref);
        if (mounted) context.go(AppRoutes.course(draft.courseId!, justSaved: true));
      } else {
        final course = await repo.createCourse(draft: draft, stops: stops);
        invalidateCourseData(ref);
        // 코스를 만들었으면 지금까지 저장한 곳은 홈 제안에서 뺀다
        ref.read(homeNudgeSeenAtProvider.notifier).markSeen();
        // 완료 화면 없이 바로 상세로 (위저드 화면은 스택에서 지워 뒤로 가면 코스 목록)
        if (mounted) context.go(AppRoutes.course(course.id, justSaved: true));
      }
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
      body = _Waiting(title: draft.name, date: draft.date);
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
                        : CourseTimeline(
                            stops: state.stops,
                            highlightIds: state.changedIds,
                            loadingIds: state.loadingIds,
                            onTapStop: busy ? null : (s, _) => showResultSheet(context, ref, s),
                            onMore: busy ? null : (s, _) => showResultSheet(context, ref, s),
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
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 기다리는 동안: 결과와 같은 자리에 뼈대(제목 → 지도 자리의 단계 표시 → 일정)
class _Waiting extends StatelessWidget {
  const _Waiting({required this.title, required this.date});
  final String title;
  final DateTime? date;

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
              const AppCard(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: SizedBox(height: 160, child: _Stages()),
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

/// 단계 표시 — 앱이 정한 안내 문구(서버 진행률 아님). 마지막 단계에서 멈춘다.
class _Stages extends StatefulWidget {
  const _Stages();

  @override
  State<_Stages> createState() => _StagesState();
}

class _StagesState extends State<_Stages> {
  static const _labels = ['장소 위치 확인', '취향 반영', '동선 정리'];
  int _now = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1100), (_) {
      if (_now < _labels.length - 1) setState(() => _now++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: '${_labels[_now]} 중',
      excludeSemantics: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _labels.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: 20,
                    child: i < _now
                        ? Container(
                            decoration: const BoxDecoration(color: AppColors.successSoft, shape: BoxShape.circle),
                            child: const Icon(Icons.check_rounded, size: 14, color: AppColors.success),
                          )
                        : i == _now
                            ? const CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)
                            : Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.progressInactive, width: 2),
                                ),
                              ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _labels[i],
                    style: AppTypography.bodyStrong.copyWith(
                      color: i == _now ? AppColors.textPrimary : (i < _now ? AppColors.textSecondary : AppColors.textTertiary),
                      fontWeight: i == _now ? FontWeight.w700 : FontWeight.w500,
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
