import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/repositories.dart';
import '../../../../app/routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/widgets/bottom_cta.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/headers.dart';
import '../../../../core/widgets/overlays.dart';
import '../../../../core/widgets/states.dart';
import '../../../../core/widgets/surfaces.dart';
import '../../../place/domain/place.dart';
import '../../domain/course_models.dart';
import '../course_providers.dart';
import '../recommendation_controller.dart';
import '../widgets/course_edit_actions.dart';
import '../widgets/course_timeline.dart';
import '../widgets/recommending_banner.dart';

/// 저장한 코스 편집 (상세 → "편집"). 4단계 편집과 같은 목록·시트를 쓴다.
/// 빼기(X, 이번만) · 차단(타일 시트) · 순서 · 장소 추가 · 다시 추천을 하고 "저장"해야 코스에 반영된다.
class CourseEditPage extends ConsumerStatefulWidget {
  const CourseEditPage({super.key, required this.courseId});
  final String courseId;

  @override
  ConsumerState<CourseEditPage> createState() => _CourseEditPageState();
}

class _CourseEditPageState extends ConsumerState<CourseEditPage> {
  Course? _course;
  Object? _error;
  bool _saving = false;

  RecommendationController get _rec => ref.read(recommendationProvider.notifier);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final course = await ref.read(courseDetailProvider(widget.courseId).future);
      _rec.startEditing(course);
      if (mounted) setState(() => _course = course);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _close() async {
    if (_rec.isDirty) {
      final leave = await showConfirmDialog(
        context,
        title: '변경한 내용을 저장하지 않고 나갈까요?',
        confirmLabel: '나가기',
        destructive: true,
      );
      if (!leave) return;
    }
    if (mounted) context.pop();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final stops = ref.read(recommendationProvider).stops;
      await ref.read(courseRepositoryProvider).updateCourseStops(courseId: widget.courseId, stops: stops);
      invalidateCourseData(ref);
      if (!mounted) return;
      showAppSnackBar(context, '코스를 저장했어요');
      context.pop();
    } catch (e) {
      if (mounted) showAppSnackBar(context, failureMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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

  Widget _editBody(Course course, RecommendationState state, bool busy) {
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      children: [
        CourseHero(title: course.title, meta: courseMetaLine(date: course.date, start: course.startTime)),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: AppSpacing.screenPadding,
          child: SectionCard(
            title: '일정 편집',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.loading)
                  RecommendingBanner(onCancel: () => cancelRecommendationWithNotice(context, ref)),
                CourseEditList(
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
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH + 6, AppSpacing.xs, AppSpacing.screenH, 0),
          child: Text('시간과 이동 정보는 저장하면 다시 계산돼요.', style: AppTypography.caption),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recommendationProvider);
    final course = _course;
    final busy = state.loading || _saving;

    final Widget body;
    if (course != null) {
      body = _editBody(course, state, busy);
    } else if (_error != null) {
      body = AppErrorState(error: _error!, onRetry: _load);
    } else {
      body = const AppLoading();
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              PlainHeader(leadingIcon: Icons.close_rounded, leadingTooltip: '닫기', onLeading: _close),
              Expanded(child: body),
              if (course != null)
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
                        child: AppButton(
                          label: '저장',
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
