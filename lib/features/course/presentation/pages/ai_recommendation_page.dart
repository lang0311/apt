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
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/bottom_cta.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/chips.dart';
import '../../../../core/widgets/headers.dart';
import '../../../../core/widgets/overlays.dart';
import '../../../../core/widgets/staged_loading.dart';
import '../../../../core/widgets/states.dart';
import '../../../../core/widgets/surfaces.dart';
import '../../../place/domain/place.dart';
import '../../domain/course_models.dart';
import '../course_draft_controller.dart';
import '../course_providers.dart';
import '../recommendation_controller.dart';
import '../widgets/course_place_row.dart';
import '../widgets/course_route_map.dart';
import 'add_places_page.dart';

/// #30 AI 추천·동선 검토 (4/4) — 루프 화면.
/// 편집(교체/삭제/순서/추가) → "다른 추천" → 재추천을 반복할 수 있다. 진행 바는 4/4 유지.
class AiRecommendationPage extends ConsumerStatefulWidget {
  const AiRecommendationPage({super.key});

  @override
  ConsumerState<AiRecommendationPage> createState() => _AiRecommendationPageState();
}

class _AiRecommendationPageState extends ConsumerState<AiRecommendationPage> {
  bool _completing = false;

  RecommendationController get _rec => ref.read(recommendationProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final stale = await _rec.syncWithDraft();
      if (stale && mounted) showAppSnackBar(context, '선택한 장소가 바뀌어 새로 추천받았어요.');
    });
  }

  Future<void> _again() async {
    await _rec.recommendAgain();
    _showErrorIfAny();
  }

  void _showErrorIfAny() {
    final e = ref.read(recommendationProvider).error;
    if (e != null && mounted) showAppSnackBar(context, '다른 추천을 받지 못했어요. ${failureMessage(e)}');
  }

  Future<void> _addPlaces() async {
    final picked = await context.push<List<Place>>(
      AppRoutes.pickPlaces,
      extra: AddPlacesArgs(excludedPlaceIds: ref.read(recommendationProvider).stops.map((s) => s.place.id).toSet()),
    );
    if (picked != null && picked.isNotEmpty) _rec.addPlaces(picked);
  }

  void _edit(CourseStop stop, int index, int count) {
    showActionSheet(context, title: stop.place.name, actions: [
      if (index > 0) SheetAction(label: '앞으로 이동', icon: Icons.arrow_upward_rounded, onTap: () => _rec.moveStop(index, index - 1)),
      if (index < count - 1)
        SheetAction(label: '뒤로 이동', icon: Icons.arrow_downward_rounded, onTap: () => _rec.moveStop(index, index + 2)),
      if (stop.isAi)
        SheetAction(
          label: '다른 장소로 바꾸기',
          icon: Icons.autorenew_rounded,
          onTap: () async {
            await _rec.replaceAi(stop);
            _showErrorIfAny();
          },
        ),
      SheetAction(label: '코스에서 빼기', icon: Icons.delete_outline_rounded, destructive: true, onTap: () => _rec.removeStop(stop)),
    ]);
  }

  Future<void> _complete() async {
    final draft = ref.read(courseDraftProvider);
    final stops = ref.read(recommendationProvider).stops;
    final repo = ref.read(courseRepositoryProvider);
    setState(() => _completing = true);
    try {
      if (draft.isEditingExisting) {
        // 완성된 코스의 루프 재진입: 변경 내용을 코스에 바로 반영
        await repo.updateCourseStops(courseId: draft.courseId!, stops: stops);
        invalidateCourseData(ref);
        if (mounted) {
          showAppSnackBar(context, '코스를 업데이트했어요.');
          context.pop();
        }
      } else {
        final course = await repo.createCourse(draft: draft, stops: stops);
        invalidateCourseData(ref);
        if (mounted) context.go(AppRoutes.courseNewDone(course.id));
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, failureMessage(e));
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recommendationProvider);
    final editing = ref.watch(courseDraftProvider.select((d) => d.isEditingExisting));

    final Widget body;
    if (!state.hasResult && state.error != null) {
      body = AppErrorState(error: state.error!, title: '추천을 받지 못했어요', onRetry: () => _rec.syncWithDraft());
    } else if (!state.hasResult) {
      body = const StagedLoading(messages: [
        '선택한 장소와 동선을 살펴보고 있어요',
        '취향에 맞는 장소를 고르고 있어요',
        '빈 시간에 어울리는 곳을 채우고 있어요',
      ]);
    } else {
      body = _Result(state: state, onEdit: _edit, onAdd: _addPlaces);
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            StepHeader(title: editing ? '다른 추천 받기' : 'AI 코스 추천', step: 4),
            if (state.loading && state.hasResult)
              const Padding(
                padding: EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xs, AppSpacing.screenH, 0),
                child: LinearProgressIndicator(minHeight: 3, color: AppColors.ai, backgroundColor: AppColors.aiSoft),
              ),
            Expanded(child: body),
            if (state.hasResult)
              BottomCta(
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: AppButton.outline(label: '다른 추천', loading: state.loading, onPressed: _completing ? null : _again),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 3,
                      child: AppButton(
                        label: editing ? '변경 내용 저장하기' : '이 코스로 완성하기',
                        loading: _completing,
                        onPressed: state.loading || state.stops.isEmpty ? null : _complete,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.state, required this.onEdit, required this.onAdd});
  final RecommendationState state;
  final void Function(CourseStop stop, int index, int count) onEdit;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final rec = state.recommendation!;
    final stops = state.stops;
    final numbers = userStopNumbers(stops);
    final hasAi = stops.any((s) => s.isAi);

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.lg, AppSpacing.screenH, AppSpacing.lg),
      children: [
        Text(rec.headline ?? 'AI가 코스를 추천했어요', style: AppTypography.title),
        if (rec.description != null) ...[
          const SizedBox(height: 4),
          Text(rec.description!, style: AppTypography.body),
        ],
        if (rec.preferenceMix.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _PreferenceMixBar(mix: rec.preferenceMix),
        ],
        const SizedBox(height: AppSpacing.md),
        CourseRouteMap(stops: stops),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.xs, AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text('추천 동선', style: AppTypography.section)),
                  const AppTag('AI 추천', tone: AppTagTone.ai, icon: Icons.auto_awesome),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ),
              if (!hasAi)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm, right: AppSpacing.sm),
                  // 추천 0건 — 디자인 없음 (docs/07 §3)
                  child: Text('지금 조건에 맞는 추천 장소를 찾지 못했어요. 장소나 분위기를 바꿔 다시 추천받아 보세요.', style: AppTypography.meta),
                ),
              const SizedBox(height: AppSpacing.xs),
              for (var i = 0; i < stops.length; i++)
                _StopRow(stop: stops[i], number: numbers[i], onEdit: () => onEdit(stops[i], i, stops.length)),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('장소 추가'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary, alignment: Alignment.centerLeft),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({required this.stop, required this.number, required this.onEdit});
  final CourseStop stop;
  final int? number;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final subtitle = stop.isAi
        ? ['AI 추천', ?stop.aiReason].join(' · ')
        : [
            '선택 장소',
            if (stop.arrivalTime != null) formatClock(stop.arrivalTime!),
          ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          AppNetworkImage(url: stop.place.imageUrl, width: 52, height: 52, radius: 12),
          const SizedBox(width: AppSpacing.sm),
          StopMarker(source: stop.source, number: number),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stop.place.name, style: AppTypography.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  subtitle,
                  style: AppTypography.caption.copyWith(
                    color: stop.isAi ? AppColors.ai : null,
                    fontWeight: stop.isAi ? FontWeight.w700 : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '${stop.place.name} 편집',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 20),
          ),
        ],
      ),
    );
  }
}

/// 파티 취향 반영 비율 (값은 서버)
class _PreferenceMixBar extends StatelessWidget {
  const _PreferenceMixBar({required this.mix});
  final List<PreferenceShare> mix;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(color: AppColors.extractSoft, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          const Icon(Icons.groups_rounded, color: AppColors.extract, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              ['파티 취향 반영', for (final m in mix) '${m.label} ${m.percent}%'].join(' · '),
              style: AppTypography.label.copyWith(color: AppColors.extract),
            ),
          ),
        ],
      ),
    );
  }
}
