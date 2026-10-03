import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/bottom_cta.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/headers.dart';
import '../../../../core/widgets/overlays.dart';
import '../../../../core/widgets/states.dart';
import '../../../../core/widgets/surfaces.dart';
import '../../domain/course_models.dart';
import '../course_providers.dart';
import '../widgets/course_place_row.dart';
import '../widgets/course_route_map.dart';

/// #31 코스 생성 완료
class CourseDonePage extends ConsumerWidget {
  const CourseDonePage({super.key, required this.courseId});
  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = ref.watch(courseDetailProvider(courseId));
    void close() => context.go(AppRoutes.courses);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SubPageHeader(
              title: '코스 완성',
              onBack: close,
              trailing: AppTextLink(label: '닫기', onPressed: close),
            ),
            Expanded(
              child: AsyncValueView<Course>(
                value: course,
                onRetry: () => ref.invalidate(courseDetailProvider(courseId)),
                data: (c) => ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xs, AppSpacing.screenH, AppSpacing.lg),
                  children: [
                    const Center(child: IconCircle(icon: Icons.check_rounded, size: 84)),
                    const SizedBox(height: AppSpacing.md),
                    Text('코스가 완성됐어요!', style: AppTypography.display, textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Text('저장한 장소와 AI 추천을 한 코스에 담았어요.', style: AppTypography.body, textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.xl),
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CourseRouteMap(stops: c.stops, height: 180),
                          const SizedBox(height: AppSpacing.md),
                          Text(c.title, style: AppTypography.title),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (c.date != null) formatDate(c.date!),
                              if (c.isParty) '파티 ${c.memberCount}명',
                              '장소 ${c.stops.length}곳',
                            ].join(' · '),
                            style: AppTypography.meta,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          for (final (i, s) in c.stops.indexed)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  StopMarker(source: s.source, number: userStopNumbers(c.stops)[i]),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(child: Text(s.place.name, style: AppTypography.bodyStrong)),
                                  Text(
                                    s.isAi ? 'AI 추천' : '선택 장소',
                                    style: AppTypography.caption.copyWith(
                                      color: s.isAi ? AppColors.ai : null,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            BottomCta(
              child: Row(
                children: [
                  Expanded(
                    child: AppButton.outline(
                      label: '코스 공유',
                      icon: Icons.share_outlined,
                      // 코스 공유 화면/시트는 디자인 없음 (docs/07 §3)
                      onPressed: () => showAppSnackBar(context, '코스 공유는 준비 중이에요.'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppButton(label: '코스 보기', onPressed: () => context.go(AppRoutes.course(courseId))),
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
