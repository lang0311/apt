import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/headers.dart';
import '../../../../core/widgets/overlays.dart';
import '../../../../core/widgets/segmented_tabs.dart';
import '../../../../core/widgets/states.dart';
import '../../domain/course_models.dart';
import '../course_draft_controller.dart';
import '../course_providers.dart';
import '../widgets/course_summary_card.dart';

/// #21 코스 빈 상태 / #22 코스 목록 [내 코스 | 모임 / 파티 코스]
class CoursesPage extends ConsumerStatefulWidget {
  const CoursesPage({super.key});

  @override
  ConsumerState<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends ConsumerState<CoursesPage> {
  int _tab = 0;
  bool _showAllMine = false;

  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(myCoursesProvider);
    final party = ref.watch(partyCoursesProvider);
    final loaded = mine.hasValue && party.hasValue;
    final isEmpty = loaded && mine.value!.isEmpty && party.value!.isEmpty;

    void retry() {
      ref.invalidate(myCoursesProvider);
      ref.invalidate(partyCoursesProvider);
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            retry();
            await ref.read(myCoursesProvider.future).then((_) {}, onError: (_) {});
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
            children: [
              PageTitleHeader(
                title: '코스',
                subtitle: isEmpty ? '좋아하는 장소로 나만의 하루를 완성해요.' : '소중한 여행을 더 특별하게',
                trailing: isEmpty
                    ? null
                    : AppIconBox(icon: Icons.add_rounded, size: 44, tooltip: '코스 만들기', onPressed: () => startCourseWizard(context, ref)),
              ),
              if (mine.hasError || party.hasError)
                AppErrorState(error: (mine.error ?? party.error)!, onRetry: retry)
              else if (!loaded)
                const SkeletonList()
              else if (isEmpty)
                const _EmptyCourses()
              else ...[
                Padding(
                  padding: AppSpacing.screenPadding,
                  child: SegmentedTabs(
                    labels: const ['내 코스', '모임 / 파티 코스'],
                    selectedIndex: _tab,
                    style: SegmentedStyle.pills,
                    onChanged: (i) => setState(() => _tab = i),
                  ),
                ),
                if (_tab == 0) ...[
                  _section(
                    title: '내 코스 ${mine.value!.length}',
                    courses: _showAllMine ? mine.value! : mine.value!.take(3).toList(),
                    more: mine.value!.length > 3 && !_showAllMine ? () => setState(() => _showAllMine = true) : null,
                    emptyText: '아직 혼자 만든 코스가 없어요.',
                  ),
                  _section(
                    title: '모임 / 파티 코스',
                    courses: party.value!.take(2).toList(),
                    more: party.value!.length > 2 ? () => setState(() => _tab = 1) : null,
                    emptyText: '친구와 함께 만드는 코스가 여기에 표시돼요.',
                  ),
                ] else
                  _section(
                    title: '모임 / 파티 코스 ${party.value!.length}',
                    courses: party.value!,
                    emptyText: '초대받았거나 함께 만든 코스가 여기에 표시돼요.',
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _section({required String title, required List<CourseSummary> courses, VoidCallback? more, required String emptyText}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: title, actionLabel: more == null ? null : '더보기', onAction: more),
        if (courses.isEmpty)
          Padding(padding: AppSpacing.screenPadding, child: Text(emptyText, style: AppTypography.body))
        else
          for (final c in courses)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.sm),
              child: CourseSummaryCard(course: c, onTap: () => context.push(AppRoutes.course(c.id))),
            ),
      ],
    );
  }
}

class _EmptyCourses extends ConsumerWidget {
  const _EmptyCourses();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggested = ref.watch(suggestedCoursesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppEmptyState(
          icon: Icons.map_outlined,
          title: '아직 저장된 코스가 없어요',
          description: '가고 싶은 장소를 모아\n나만의 여행 코스를 만들어보세요.',
          actionLabel: '+ 첫 코스 만들기',
          onAction: () => startCourseWizard(context, ref),
        ),
        // 추천 코스는 서버 제공 — 없으면 섹션을 숨긴다
        if (suggested.value?.isNotEmpty ?? false) ...[
          const SectionHeader(title: '이런 코스는 어때요?', padding: EdgeInsets.fromLTRB(AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.sm)),
          Padding(
            padding: AppSpacing.screenPadding,
            child: Row(
              children: [
                for (final (i, s) in suggested.value!.take(2).indexed) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      // 추천 코스 상세 화면은 디자인 없음
                      onTap: () => showAppSnackBar(context, '추천 코스 상세는 준비 중이에요.'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(aspectRatio: 2.1, child: AppNetworkImage(url: s.imageUrl, radius: 16, width: double.infinity)),
                          const SizedBox(height: AppSpacing.xs),
                          Text(s.title, style: AppTypography.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(
                            ['${s.placeCount}곳', ?s.durationLabel].join(' · '),
                            style: AppTypography.meta.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
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
