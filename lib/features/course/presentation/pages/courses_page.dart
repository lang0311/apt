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
import '../../../home/presentation/widgets/home_sections.dart';
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
          onRefresh: () {
            retry();
            return awaitRefresh(context, [ref.read(myCoursesProvider.future), ref.read(partyCoursesProvider.future)]);
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
              // 새로고침이 실패해도 이전 목록이 있으면 그대로 둔다 (알림은 스낵바)
              if (!loaded && (mine.hasError || party.hasError))
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
                    onChanged: (i) => setState(() => _tab = i),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _Split(courses: _tab == 0 ? mine.value! : party.value!, others: _tab == 0 ? party.value! : const []),
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
  const _Split({required this.courses, this.others = const []});
  final List<CourseSummary> courses;

  /// 내 코스 탭에서만: 함께하는 코스. 내 예정 코스가 없을 때 가장 가까운 한 곳으로 가는 줄을 보여 준다
  final List<CourseSummary> others;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming = [for (final c in courses) if (c.date == null || daysUntil(c.date!) >= 0) c]
      ..sort((a, b) => (a.date ?? DateTime(9999)).compareTo(b.date ?? DateTime(9999)));
    final otherNext = ([for (final c in others) if (c.date != null && daysUntil(c.date!) >= 0) c]
          ..sort((a, b) => a.date!.compareTo(b.date!)))
        .firstOrNull;
    final past = [for (final c in courses) if (c.date != null && daysUntil(c.date!) < 0) c]
      ..sort((a, b) => b.date!.compareTo(a.date!));

    Widget rows(List<CourseSummary> list) => DividedRows(
          indent: SectionCard.innerPadding + 48 + AppSpacing.sm,
          children: [
            for (final c in list) CourseSummaryRow(course: c, onTap: () => context.push(AppRoutes.course(c.id))),
          ],
        );

    // 지난 코스는 달마다 묶는다 (최근 달부터)
    final months = <String, List<CourseSummary>>{};
    for (final c in past) {
      months.putIfAbsent(c.date!.year == DateTime.now().year ? '${c.date!.month}월' : '${c.date!.year}년 ${c.date!.month}월', () => []).add(c);
    }

    return Padding(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 가장 가까운 코스 하나는 홈과 같은 큰 카드, 나머지는 아래 목록
          if (upcoming.isEmpty)
            SectionCard(
              title: '다가오는 코스',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (otherNext != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: SectionCard.innerPadding),
                      child: Text('내가 만든 예정 코스는 없어요', style: AppTypography.meta),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _OtherUpcomingRow(course: otherNext, onTap: () => context.push(AppRoutes.course(otherNext.id))),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  _EmptyLine(
                    text: otherNext == null ? '예정된 코스가 없어요' : null,
                    actionLabel: '코스 만들기',
                    onAction: () => startCourseWizard(context, ref),
                  ),
                ],
              ),
            )
          else ...[
            HomeCourseCard(
              course: upcoming.first,
              isToday: upcoming.first.date != null && daysUntil(upcoming.first.date!) == 0,
              moreCount: 0,
              onOpen: () => context.push(AppRoutes.course(upcoming.first.id)),
              onMore: () {},
            ),
            if (upcoming.length > 1) ...[
              const SizedBox(height: AppSpacing.sm),
              SectionCard(title: '다가오는 코스 ${upcoming.length - 1}개 더', child: rows(upcoming.skip(1).toList())),
            ],
          ],
          const SizedBox(height: AppSpacing.sm),
          SectionCard(
            title: '지난 코스',
            child: past.isEmpty
                ? const _EmptyLine(text: '아직 지난 여행이 없어요')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, e) in months.entries.indexed) ...[
                        Padding(
                          padding: EdgeInsets.fromLTRB(SectionCard.innerPadding, i == 0 ? 0 : AppSpacing.sm, SectionCard.innerPadding, 0),
                          child: Text(e.key, style: AppTypography.meta.copyWith(fontWeight: FontWeight.w700)),
                        ),
                        rows(e.value),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// 내 예정 코스가 없을 때 함께하는 코스 중 가장 가까운 코스로 가는 줄 (홈의 오늘 카드와 코스 탭이 어긋나 보이지 않게)
class _OtherUpcomingRow extends StatelessWidget {
  const _OtherUpcomingRow({required this.course, required this.onTap});
  final CourseSummary course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sub = [
      '함께하는 코스',
      if (course.startTime != null) '${formatTimeOfDay(course.startTime!)} 출발',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SectionCard.innerPadding),
      child: Material(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                Text(ddayLabel(course.date!), style: AppTypography.label.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(course.title, style: AppTypography.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(sub, style: AppTypography.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 컨테이너 안 한 줄 빈 상태
class _EmptyLine extends StatelessWidget {
  const _EmptyLine({this.text, this.actionLabel, this.onAction});
  final String? text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(SectionCard.innerPadding, 0, SectionCard.innerPadding, AppSpacing.xxs),
      // 문구와 링크를 '·'로 잇지 않고 두 줄로 나눈다
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (text != null) Text(text!, style: AppTypography.meta),
          if (actionLabel != null)
            // AppTextLink의 좌우 여백(4)만큼 당겨 위 문구와 글자 왼쪽을 맞춘다
            Transform.translate(
              offset: const Offset(-4, 0),
              child: AppTextLink(label: actionLabel!, onPressed: onAction, style: AppTypography.meta.copyWith(fontWeight: FontWeight.w700)),
            ),
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
                      borderRadius: BorderRadius.circular(AppRadius.medium),
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
