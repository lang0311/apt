import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/headers.dart';
import '../../../core/widgets/overlays.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/surfaces.dart';
import '../../course/presentation/course_draft_controller.dart';
import '../../course/presentation/course_providers.dart';
import '../../extraction/presentation/extraction_providers.dart';
import '../../saved/domain/saved_models.dart';
import '../../saved/presentation/saved_providers.dart';
import '../domain/home_top.dart';
import 'home_providers.dart';
import 'widgets/home_sections.dart';

/// #9 홈. 지도 앱처럼 만들지 않는다 — 저장·코스로 이어지는 허브.
/// 맨 위 자리 하나만 상황(처음 / 저장만 / 다가오는 코스 / 오늘)에 따라 바뀌고,
/// 그 아래는 최근 저장한 곳 → 이런 코스는 어때요? → 지금 뜨는 장소 순서로 고정한다 (docs/05 #9, 07 D20).
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  /// 섹션 묶음 바깥 여백 (컨테이너 안 여백은 SectionCard.innerPadding)
  static const _outerPadding = AppSpacing.sm;
  static const _sectionGap = 10.0;

  Future<void> _refresh(BuildContext context, WidgetRef ref) {
    ref.invalidate(homeStatsProvider);
    ref.invalidate(recentExtractionsProvider);
    ref.invalidate(trendingPlacesProvider);
    ref.invalidate(suggestedCoursesProvider);
    ref.invalidate(activeCoursesProvider);
    ref.invalidate(savedPlacesProvider);
    return awaitRefresh(context, [
      ref.read(activeCoursesProvider.future),
      ref.read(homeStatsProvider.future),
      ref.read(recentExtractionsProvider.future),
      ref.read(trendingPlacesProvider.future),
      ref.read(suggestedCoursesProvider.future),
    ]);
  }

  Future<void> _dismissNudge(BuildContext context, WidgetRef ref) async {
    final previous = await ref.read(homeNudgeSeenAtProvider.notifier).markSeen();
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      '코스 추천을 숨겼어요',
      actionLabel: '되돌리기',
      onAction: () => ref.read(homeNudgeSeenAtProvider.notifier).restore(previous),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(activeCoursesProvider);
    final stats = ref.watch(homeStatsProvider);
    final recent = ref.watch(recentExtractionsProvider);
    final seenAt = ref.watch(homeNudgeSeenAtProvider);
    final suggested = ref.watch(suggestedCoursesProvider);
    final trending = ref.watch(trendingPlacesProvider);
    final saved = ref.watch(savedPlacesProvider(const SavedPlaceQuery()));

    // 맨 위 자리는 코스·저장 수·최근 저장·제안 기록이 모두 있어야 고를 수 있다.
    // 통계·최근 저장이 실패해도 코스가 있으면 코스 카드는 보여 준다.
    // 새로고침 중(isLoading이어도 이전 값이 있음)에는 뼈대로 바꾸지 않는다.
    bool settled(AsyncValue<Object?> v) => v.hasValue || v.hasError;
    final topReady = courses.hasValue && settled(stats) && settled(recent) && settled(seenAt);
    final HomeTop? top = topReady
        ? resolveHomeTop(
            courses: courses.value!,
            savedPlaceCount: stats.value?.savedPlaceCount ?? 0,
            recentSaves: recent.value ?? const [],
            nudgeSeenAt: seenAt.value,
          )
        : null;

    final Widget? topWidget = switch (top) {
      null when courses.hasError => AppErrorState(
          error: courses.error!,
          compact: true,
          onRetry: () => ref.invalidate(activeCoursesProvider),
        ),
      null => const SkeletonBox(height: 104, radius: 20),
      HomeTopStart() => HomeStartGuide(onPasteLink: () => context.go(AppRoutes.extract)),
      HomeTopNudge(:final newSaves) when newSaves.isNotEmpty => NewSavesNudge(
          items: newSaves,
          onTap: () => startCourseWizard(context, ref, places: [for (final r in newSaves) r.place]),
          onClose: () => _dismissNudge(context, ref),
        ),
      HomeTopNudge() => null,
      HomeTopCourse(:final course, :final isToday, :final moreCount) => HomeCourseCard(
          course: course,
          isToday: isToday,
          moreCount: moreCount,
          onOpen: () => context.push(AppRoutes.course(course.id)),
          onMore: () => context.go(AppRoutes.courses),
        ),
    };

    final isFirstUse = top is HomeTopStart;
    final sections = <Widget>[
      ?topWidget,
      if (top is HomeTopCourse)
        HomeQuickActions(
          onSavePlace: () => context.go(AppRoutes.extract),
          onNewCourse: () => startCourseWizard(context, ref),
        ),
      // 저장한 곳을 지역으로 묶어 코스 만들기로 (주소에 구 · 시가 있는 곳만, 없으면 섹션째 숨긴다)
      if (!isFirstUse && HomeRegionGroups.groups([for (final i in saved.value ?? const <SavedPlaceItem>[]) i.place]).isNotEmpty)
        SectionCard(
          title: '지역별로 시작하기',
          actionLabel: '모두 보기',
          onAction: () => context.go(AppRoutes.saved),
          child: HomeRegionGroups(
            places: [for (final i in saved.value!) i.place],
            onStart: (region) => startCourseWizard(context, ref, region: region),
            onOpenRegion: (_) => context.go(AppRoutes.saved),
          ),
        ),
      if (!isFirstUse)
        ?_section(
          value: recent,
          title: '최근 저장한 곳',
          actionLabel: '모두 보기',
          onAction: () => context.go(AppRoutes.saved),
          loadingHeight: 128,
          onRetry: () => ref.invalidate(recentExtractionsProvider),
          builder: (items) => RecentSavedStrip(items: items),
        ),
      if (!isFirstUse)
        ?_section(
          value: suggested,
          title: '이런 코스는 어때요?',
          loadingHeight: 158,
          onRetry: () => ref.invalidate(suggestedCoursesProvider),
          // 추천 코스 상세 화면은 디자인 없음
          builder: (courses) => SuggestedCourseStrip(courses: courses, onTap: (_) => showAppSnackBar(context, '추천 코스 상세는 준비 중이에요.')),
        ),
      ?_section(
        value: trending,
        title: '지금 뜨는 장소',
        actionLabel: '모두 보기',
        onAction: () => showAppSnackBar(context, '전체 목록은 준비 중이에요.'),
        loadingHeight: 200,
        onRetry: () => ref.invalidate(trendingPlacesProvider),
        builder: (places) => TrendingPlaceGrid(places: places),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _refresh(context, ref),
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
            children: [
              PageTitleHeader(
                title: '홈',
                trailing: AppIconBox(
                  icon: Icons.notifications_none_rounded,
                  size: 44,
                  tooltip: '알림',
                  // 알림 화면은 디자인 없음 (docs/07 §3)
                  onPressed: () => showAppSnackBar(context, '알림은 준비 중이에요.'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: _outerPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < sections.length; i++) ...[
                      if (i > 0) const SizedBox(height: _sectionGap),
                      sections[i],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 섹션 하나 = SectionCard 하나. 데이터가 비면 섹션째 숨기고, 실패하면 그 컨테이너 안에만 오류를 보여 준다.
  Widget? _section<T>({
    required AsyncValue<List<T>> value,
    required String title,
    required double loadingHeight,
    required VoidCallback onRetry,
    required Widget Function(List<T>) builder,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    if (value.hasValue && value.value!.isEmpty) return null;
    return SectionCard(
      title: title,
      actionLabel: value.hasValue ? actionLabel : null,
      onAction: onAction,
      child: AsyncValueView<List<T>>(
        value: value,
        compactError: true,
        onRetry: onRetry,
        loading: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SectionCard.innerPadding),
          child: SkeletonBox(height: loadingHeight, radius: 14),
        ),
        data: builder,
      ),
    );
  }
}
