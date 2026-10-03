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
import '../../../../core/widgets/chips.dart';
import '../../../../core/widgets/headers.dart';
import '../../../../core/widgets/overlays.dart';
import '../../../../core/widgets/states.dart';
import '../../../../core/widgets/surfaces.dart';
import '../../../place/domain/place.dart';
import '../../domain/course_models.dart';
import '../course_draft_controller.dart';
import '../course_providers.dart';
import '../widgets/course_place_row.dart';
import '../widgets/course_route_map.dart';
import 'add_places_page.dart';

/// #32 코스 상세·관리. `다른 추천 받기`로 4/4 루프에 재진입한다.
class CourseDetailPage extends ConsumerStatefulWidget {
  const CourseDetailPage({super.key, required this.courseId});
  final String courseId;

  @override
  ConsumerState<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends ConsumerState<CourseDetailPage> {
  /// 순서 편집 중인 목록 (null = 편집 아님)
  List<CourseStop>? _editing;
  bool _saving = false;

  Future<void> _save(List<CourseStop> stops, {String done = '코스를 업데이트했어요.'}) async {
    setState(() => _saving = true);
    try {
      await ref.read(courseRepositoryProvider).updateCourseStops(courseId: widget.courseId, stops: stops);
      invalidateCourseData(ref);
      if (mounted) {
        setState(() => _editing = null);
        showAppSnackBar(context, done);
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, failureMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addPlaces(Course c) async {
    final picked = await context.push<List<Place>>(
      AppRoutes.pickPlaces,
      extra: AddPlacesArgs(excludedPlaceIds: c.stops.map((s) => s.place.id).toSet()),
    );
    if (picked == null || picked.isEmpty) return;
    // 이동 시간/도착 시각은 서버가 다시 계산한다 (NEEDS BACKEND)
    await _save(
      [...c.stops, for (final p in picked) CourseStop(place: p, source: PlaceSource.user)],
      done: '${picked.length}곳을 코스에 추가했어요.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final course = ref.watch(courseDetailProvider(widget.courseId));
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SubPageHeader(
              title: '코스 상세',
              trailing: IconButton(
                tooltip: '코스 메뉴',
                icon: const Icon(Icons.more_horiz_rounded, color: AppColors.textPrimary),
                // 코스 ⋯ 메뉴(삭제·나가기 등)는 정책/디자인 확정 필요 (docs/07 §3)
                onPressed: () => showAppSnackBar(context, '코스 관리 메뉴는 준비 중이에요.'),
              ),
            ),
            Expanded(
              child: AsyncValueView<Course>(
                value: course,
                onRetry: () => ref.invalidate(courseDetailProvider(widget.courseId)),
                data: (c) => _body(c),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(Course c) {
    final stops = _editing ?? c.stops;
    final numbers = userStopNumbers(stops);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xs, AppSpacing.screenH, AppSpacing.lg),
            children: [
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.title, style: AppTypography.display),
                    const SizedBox(height: 4),
                    Text(
                      [if (c.date != null) formatDate(c.date!), if (c.isParty) '파티 ${c.memberCount}명'].join(' · '),
                      style: AppTypography.body,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        AppTag('장소 ${c.stops.length}곳', tone: AppTagTone.primary),
                        if (c.totalDuration != null) AppTag(formatDuration(c.totalDuration!), tone: AppTagTone.primary),
                        if (c.isShared) const AppTag('공유됨', tone: AppTagTone.primary),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Stack(
                children: [
                  CourseRouteMap(stops: stops),
                  Positioned(
                    left: AppSpacing.sm,
                    top: AppSpacing.sm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.pillAll, boxShadow: AppShadow.soft),
                      child: Text('전체 동선', style: AppTypography.label.copyWith(color: AppColors.primary)),
                    ),
                  ),
                ],
              ),
              SectionHeader(
                title: '일정',
                padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.sm),
                trailing: c.canEdit
                    ? AppTextLink(
                        label: _editing == null ? '순서 편집' : '완료',
                        onPressed: _saving
                            ? null
                            : () => _editing == null ? setState(() => _editing = [...c.stops]) : _save(_editing!),
                      )
                    : null,
              ),
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: stops.length,
                onReorder: (o, n) => setState(() {
                  if (n > o) n -= 1;
                  _editing!.insert(n, _editing!.removeAt(o));
                }),
                itemBuilder: (_, i) {
                  final s = stops[i];
                  final time = s.arrivalTime == null ? '' : '${formatClock(s.arrivalTime!)} ';
                  final parts = [
                    if (s.isAi) 'AI 추천' else '선택 장소',
                    if (s.nextLeg != null) '다음 장소까지 ${s.nextLeg!.label}',
                  ];
                  return Padding(
                    key: ValueKey(s.place.id),
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      onTap: _editing == null ? () => context.push(AppRoutes.place(s.place.id)) : null,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          StopMarker(source: s.source, number: numbers[i], size: 40, dark: true),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$time${s.place.name}', style: AppTypography.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    if (s.nextLeg != null) ...[
                                      Icon(s.nextLeg!.mode.icon, size: 14, color: AppColors.textSecondary),
                                      const SizedBox(width: 3),
                                    ],
                                    Expanded(child: Text(parts.join(' · '), style: AppTypography.meta, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (_editing != null)
                            ReorderableDragStartListener(
                              index: i,
                              child: const Icon(Icons.drag_handle_rounded, color: AppColors.textSecondary, semanticLabel: '끌어서 순서 변경'),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        if (c.canEdit)
          BottomCta(
            child: Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: '장소 추가',
                    variant: AppButtonVariant.white,
                    loading: _saving && _editing == null,
                    onPressed: _editing == null ? () => _addPlaces(c) : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton.dark(
                    label: '다른 추천 받기',
                    onPressed: _editing == null ? () => reenterRecommendation(context, ref, c) : null,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
