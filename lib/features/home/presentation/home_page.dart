import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/headers.dart';
import '../../../core/widgets/overlays.dart';
import '../../../core/widgets/states.dart';
import '../../course/presentation/course_providers.dart';
import '../../extraction/presentation/extraction_providers.dart';
import '../../saved/presentation/widgets/collection_picker_sheet.dart';
import 'home_providers.dart';
import 'widgets/home_sections.dart';

/// #9 홈 대시보드. 지도 앱처럼 만들지 않는다 — 저장·추출·코스로 이어지는 허브.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(homeStatsProvider);
    ref.invalidate(recentExtractionsProvider);
    ref.invalidate(trendingPlacesProvider);
    ref.invalidate(activeCoursesProvider);
    await ref.read(homeStatsProvider.future).then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(homeStatsProvider);
    final recent = ref.watch(recentExtractionsProvider);
    final trending = ref.watch(trendingPlacesProvider);
    final courses = ref.watch(activeCoursesProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
            children: [
              _Greeting(),
              Padding(
                padding: AppSpacing.screenPadding,
                child: AsyncValueView(
                  value: stats,
                  compactError: true,
                  loading: const SkeletonBox(height: 120, radius: 20),
                  onRetry: () => ref.invalidate(homeStatsProvider),
                  data: (s) => HomeStatsCard(stats: s),
                ),
              ),

              SectionHeader(title: '최근 추출한 장소', actionLabel: '전체 보기', onAction: () => context.go(AppRoutes.saved)),
              AsyncValueView(
                value: recent,
                compactError: true,
                loading: const SkeletonList(count: 2),
                onRetry: () => ref.invalidate(recentExtractionsProvider),
                isEmpty: (l) => l.isEmpty,
                empty: AppEmptyState(
                  compact: true,
                  icon: Icons.link_rounded,
                  title: '아직 추출한 장소가 없어요',
                  description: '인스타그램 게시물을 "공유 → APT"로 보내거나 링크를 붙여넣어 보세요.',
                  actionLabel: '장소 추출하기',
                  onAction: () => context.go(AppRoutes.extract),
                ),
                data: (list) => Padding(
                  padding: AppSpacing.screenPadding,
                  child: Column(
                    children: [
                      for (final item in list)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: RecentExtractionCard(
                            item: item,
                            onSave: () async {
                              final ok = await showCollectionPickerSheet(context, places: [item.place]);
                              if (ok == true && context.mounted) showAppSnackBar(context, '장소를 저장했어요.');
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              SectionHeader(title: '지금 뜨는 장소', actionLabel: '전체 보기', onAction: () => showAppSnackBar(context, '전체 목록은 준비 중이에요.')),
              AsyncValueView(
                value: trending,
                compactError: true,
                loading: const Padding(padding: AppSpacing.screenPadding, child: SkeletonBox(height: 180, radius: 20)),
                onRetry: () => ref.invalidate(trendingPlacesProvider),
                isEmpty: (l) => l.isEmpty,
                empty: const AppEmptyState(compact: true, icon: Icons.local_fire_department_outlined, title: '지금 뜨는 장소를 준비하고 있어요'),
                data: (list) => SizedBox(
                  height: 196,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: AppSpacing.screenPadding,
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (_, i) => TrendingPlaceCard(place: list[i]),
                  ),
                ),
              ),

              SectionHeader(title: '내 코스 바로가기', actionLabel: '전체 보기', onAction: () => context.go(AppRoutes.courses)),
              AsyncValueView(
                value: courses,
                compactError: true,
                loading: const SkeletonList(count: 1),
                onRetry: () => ref.invalidate(activeCoursesProvider),
                isEmpty: (l) => l.isEmpty,
                empty: AppEmptyState(
                  compact: true,
                  icon: Icons.route_rounded,
                  title: '진행 중인 코스가 없어요',
                  description: '저장한 장소로 첫 코스를 만들어보세요.',
                  actionLabel: '코스 만들기',
                  onAction: () => context.go(AppRoutes.courses),
                ),
                data: (list) => Padding(
                  padding: AppSpacing.screenPadding,
                  child: Column(
                    children: [
                      for (final c in list)
                        Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm), child: ActiveCourseCard(course: c)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('홈', style: AppTypography.cardTitle),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    style: AppTypography.display,
                    children: [
                      const TextSpan(text: '오늘은 '),
                      TextSpan(
                        text: '어디로',
                        style: AppTypography.display.copyWith(
                          color: AppColors.primary,
                          backgroundColor: AppColors.primarySoft,
                        ),
                      ),
                      const TextSpan(text: ' 떠날까요?'),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text('마음에 담아둔 장소가, 오늘의 여행이 되도록.', style: AppTypography.body),
              ],
            ),
          ),
          AppIconBox(
            icon: Icons.notifications_none_rounded,
            size: 44,
            tooltip: '알림',
            // 알림 화면은 디자인 없음 (docs/07 §3)
            onPressed: () => showAppSnackBar(context, '알림은 준비 중이에요.'),
          ),
        ],
      ),
    );
  }
}
