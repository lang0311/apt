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
import '../../../../core/widgets/surfaces.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/course_models.dart';
import '../course_draft_controller.dart';
import '../course_providers.dart';
import '../widgets/course_summary_card.dart';

/// #21 코스 빈 상태 / #22 코스 목록 [내 코스 | 함께하는 코스].
/// 탭마다 자기 코스만 보여 주고, 날짜로 "다가오는 코스"와 "지난 코스"를 나눈다 (D-day는 날짜에서 계산).
class CoursesPage extends ConsumerStatefulWidget {
  const CoursesPage({super.key, this.initialTab = 0});

  /// 0 = 내 코스, 1 = 함께하는 코스 (`/courses?tab=party`, 마이 '내 기록'에서)
  final int initialTab;

  @override
  ConsumerState<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends ConsumerState<CoursesPage> {
  late int _tab = widget.initialTab;

  @override
  void didUpdateWidget(CoursesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) _tab = widget.initialTab;
  }

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
                trailing: isEmpty
                    ? null
                    : IconButton(
                        tooltip: '코스 만들기',
                        onPressed: () => startCourseWizard(context, ref),
                        icon: const Icon(Icons.add_rounded, size: 26, color: AppColors.textPrimary),
                      ),
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
                    labels: const ['내 코스', '함께하는 코스'],
                    counts: [mine.value!.length, party.value!.length],
                    selectedIndex: _tab,
                    style: SegmentedStyle.underline,
                    onChanged: (i) => setState(() => _tab = i),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _Split(courses: _tab == 0 ? mine.value! : party.value!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 다가오는 코스(가까운 순) / 지난 코스(최근 순) 두 컨테이너
class _Split extends ConsumerWidget {
  const _Split({required this.courses});
  final List<CourseSummary> courses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming = [for (final c in courses) if (c.date == null || daysUntil(c.date!) >= 0) c]
      ..sort((a, b) => (a.date ?? DateTime(9999)).compareTo(b.date ?? DateTime(9999)));
    final past = [for (final c in courses) if (c.date != null && daysUntil(c.date!) < 0) c]
      ..sort((a, b) => b.date!.compareTo(a.date!));

    Widget rows(List<CourseSummary> list) => DividedRows(
          indent: SectionCard.innerPadding + 48 + AppSpacing.sm,
          children: [
            for (final c in list) CourseSummaryRow(course: c, onTap: () => context.push(AppRoutes.course(c.id))),
          ],
        );

    return Padding(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: '다가오는 코스',
            child: upcoming.isEmpty
                ? _EmptyLine(
                    text: '예정된 코스가 없어요',
                    actionLabel: '코스 만들기',
                    onAction: () => startCourseWizard(context, ref),
                  )
                : rows(upcoming),
          ),
          const SizedBox(height: AppSpacing.sm),
          SectionCard(
            title: '지난 코스',
            child: past.isEmpty ? const _EmptyLine(text: '아직 지난 여행이 없어요') : rows(past),
          ),
        ],
      ),
    );
  }
}

/// 컨테이너 안 한 줄 빈 상태
class _EmptyLine extends StatelessWidget {
  const _EmptyLine({required this.text, this.actionLabel, this.onAction});
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(SectionCard.innerPadding, 0, SectionCard.innerPadding, AppSpacing.xxs),
      child: Row(
        children: [
          Text(text, style: AppTypography.meta),
          if (actionLabel != null) ...[
            Text(' · ', style: AppTypography.meta),
            AppTextLink(label: actionLabel!, onPressed: onAction, style: AppTypography.meta.copyWith(fontWeight: FontWeight.w700)),
          ],
        ],
      ),
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
