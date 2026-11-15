import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/surfaces.dart';
import '../../../course/domain/course_models.dart';
import '../../../course/presentation/widgets/course_thumb.dart';
import '../../../extraction/domain/extraction_models.dart';
import '../../../place/domain/place.dart';
import '../../../saved/presentation/widgets/category_style.dart';
import '../../../saved/presentation/widgets/place_image.dart';

/// ① 처음 써요 — 공유로 저장하는 3단계 + 링크 붙여넣기
class HomeStartGuide extends StatelessWidget {
  const HomeStartGuide({super.key, required this.onPasteLink});
  final VoidCallback onPasteLink;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('릴스에서 본 곳을 저장해 보세요', style: AppTypography.cardTitle),
          const SizedBox(height: AppSpacing.xxs),
          Text('저장한 곳으로 AI가 하루 코스를 이어 드려요.', style: AppTypography.meta),
          const SizedBox(height: AppSpacing.sm),
          const Row(
            children: [
              Expanded(child: _GuideStep(icon: Icons.more_vert_rounded, label: '릴스에서\n⋯ 누르기')),
              SizedBox(width: AppSpacing.xs),
              Expanded(child: _GuideStep(icon: Icons.ios_share_rounded, label: '공유\n누르기')),
              SizedBox(width: AppSpacing.xs),
              Expanded(child: _GuideStep(appMark: true, label: 'APT\n고르기')),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: '링크 붙여넣기',
            icon: Icons.link_rounded,
            variant: AppButtonVariant.white,
            height: 44,
            onPressed: onPasteLink,
          ),
        ],
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({this.icon, this.appMark = false, required this.label});
  final IconData? icon;
  final bool appMark;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      // 카드 안에 흰 칸을 또 띄우지 않는다(07 D57)
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs, horizontal: AppSpacing.xxs),
      child: Column(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: appMark ? AppColors.ink : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: appMark
                ? Text('APT', style: AppTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w800))
                : Icon(icon, size: 18, color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(label, style: AppTypography.caption, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// ② 새로 저장한 곳이 있을 때만 뜨는 한 줄 제안. 카드를 누르면 그 장소들로 코스 만들기, X로 닫는다.
class NewSavesNudge extends StatelessWidget {
  const NewSavesNudge({super.key, required this.items, required this.onTap, required this.onClose});
  final List<RecentExtraction> items;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final thumbs = items.take(3).toList();
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardAll, side: const BorderSide(color: AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.xxs, AppSpacing.sm),
          child: Row(
            children: [
              SizedBox(
                width: 36.0 + 20 * (thumbs.length - 1),
                height: 36,
                child: Stack(
                  children: [
                    for (var i = 0; i < thumbs.length; i++)
                      Positioned(
                        left: 20.0 * i,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.small)),
                          child: PlaceImage(place: thumbs[i].place, width: 32, height: 32, radius: 10, iconSize: 16),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('최근 ${items.length}곳을 저장했어요', style: AppTypography.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      '코스로 만들어 볼까요? ›',
                      style: AppTypography.meta.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose,
                tooltip: '제안 닫기',
                icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ③ 다가오는 코스 / ④ 오늘 코스. D-day(또는 '오늘')를 크게 두고 그 옆에 날짜 · 출발 시간, 이름 오른쪽에 거리 · 인원(있는 값만), 아래에 장소 순서 줄.
/// 서버가 장소 이름을 주지 않으면(목 데이터 등) 장소 줄 대신 '날짜 · n곳' 한 줄.
class HomeCourseCard extends StatelessWidget {
  const HomeCourseCard({
    super.key,
    required this.course,
    required this.isToday,
    required this.moreCount,
    required this.onOpen,
    required this.onMore,
  });

  final CourseSummary course;
  final bool isToday;
  final int moreCount;
  final VoidCallback onOpen;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final date = course.date;
    final big = AppTypography.title.copyWith(fontSize: 22, fontWeight: FontWeight.w800, height: 1.1);
    final hasStops = course.stopNames.length == course.stopCategoryKeys.length && course.stopNames.isNotEmpty;

    final Widget headline;
    if (isToday) {
      headline = Text('오늘', style: big.copyWith(color: AppColors.primary));
    } else if (date == null) {
      headline = Text('날짜 미정', style: big.copyWith(fontSize: 18, color: AppColors.textSecondary));
    } else {
      headline = Text(ddayLabel(date), style: big.copyWith(color: AppColors.primary));
    }

    final facts = <(IconData, String)>[
      if (date != null && !isToday) (Icons.calendar_today_outlined, formatMonthDayWeekday(date)),
      if (course.startTime != null) (Icons.schedule_rounded, '${formatTimeOfDay(course.startTime!)} 출발'),
      if (course.distanceKm != null) (Icons.straighten_rounded, formatDistance((course.distanceKm! * 1000).round())),
      if (course.isParty) (Icons.group_outlined, '${course.memberCount}명'),
    ];

    // 장소 줄이 있는 카드: 언제(날짜 · 출발)는 D-day 옆 한 문장으로, 거리 · 인원은 아이콘 없이 이름 오른쪽에 조용히
    final when = [
      if (date != null && !isToday) formatMonthDayWeekday(date),
      if (course.startTime != null) '${formatTimeOfDay(course.startTime!)} 출발',
    ].join(' ');
    final side = [
      if (course.distanceKm != null) formatDistance((course.distanceKm! * 1000).round()),
      if (course.isParty) '${course.memberCount}명',
    ];

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardAll, side: const BorderSide(color: AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasStops) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        headline,
                        if (when.isNotEmpty) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(child: Text(when, style: AppTypography.label, maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(child: Text(course.title, style: AppTypography.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis)),
                        for (final text in side) ...[
                          const SizedBox(width: 10),
                          Text(text, style: AppTypography.meta),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _StopStrip(keys: course.stopCategoryKeys, names: course.stopNames, isAi: course.stopIsAi),
                  ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            headline,
                            const SizedBox(height: 6),
                            Text(course.title, style: AppTypography.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (!hasStops) ...[
                              const SizedBox(height: 2),
                              Text(
                                [date == null ? '날짜 미정' : formatMonthDayWeekday(date), '${course.placeCount}곳'].join(', '),
                                style: AppTypography.meta,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (!hasStops) ...[
                        const SizedBox(width: AppSpacing.sm),
                        CourseThumb(course: course, size: 72),
                      ],
                    ],
                  ),
                  if (!hasStops && facts.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: 4,
                      children: [
                        for (final (icon, text) in facts)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(text, style: AppTypography.meta.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                            ],
                          ),
                      ],
                    ),
                  ],
                  if (isToday) ...[
                    SizedBox(height: hasStops ? AppSpacing.md : AppSpacing.sm),
                    AppButton(label: '코스 보기', height: 44, onPressed: onOpen),
                  ],
                ],
              ),
            ),
          ),
          if (!isToday && moreCount > 0) ...[
            const Divider(height: 1, indent: AppSpacing.md, endIndent: AppSpacing.md, color: AppColors.divider),
            InkWell(
              onTap: onMore,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, 14, AppSpacing.sm),
                child: Row(
                  children: [
                    Text('다가오는 코스 $moreCount개 더 보기', style: AppTypography.meta),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 장소 순서 줄: 선으로 이은 작은 업종 동그라미 + 이름(두 줄까지). 5곳까지는 모두, 6곳부터는 앞 셋 · 남은 수 · 마지막 곳.
/// AI 추천 동그라미에는 작은 ✦. 색 면을 줄여 이름이 먼저 읽히게 한다
class _StopStrip extends StatelessWidget {
  const _StopStrip({required this.keys, required this.names, required this.isAi});
  final List<String> keys;
  final List<String> names;
  final List<bool> isAi;

  @override
  Widget build(BuildContext context) {
    final n = keys.length;
    final shown = n <= 5 ? [for (var i = 0; i < n; i++) i] : [0, 1, 2, -1, n - 1];
    Widget cell(int j) {
      final i = shown[j];
      final first = j == 0;
      final last = j == shown.length - 1;
      if (i < 0) {
        return _StripCell(
          lineBefore: !first,
          lineAfter: !last,
          color: AppColors.surfaceMuted,
          label: '',
          child: Text('+${n - 4}', style: AppTypography.caption.copyWith(fontWeight: FontWeight.w700)),
        );
      }
      final style = CategoryStyle.of(keys[i]);
      return _StripCell(
        lineBefore: !first,
        lineAfter: !last,
        // 선이 비치지 않게 12% 색을 카드 바탕에 미리 섞어 불투명하게 쓴다
        color: Color.alphaBlend(style.color.withValues(alpha: 0.12), AppColors.surface),
        ai: i < isAi.length && isAi[i],
        label: names[i],
        child: Icon(style.icon, size: 16, color: style.ink),
      );
    }

    return Semantics(
      label: '장소 순서: ${names.join(', ')}',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var j = 0; j < shown.length; j++) Expanded(child: cell(j)),
          // 곳 수가 적어도 칸 폭이 너무 커지지 않게 빈 자리를 채운다
          for (var k = shown.length; k < 5; k++) const Expanded(child: SizedBox.shrink()),
        ],
      ),
    );
  }
}

class _StripCell extends StatelessWidget {
  const _StripCell({
    required this.child,
    required this.color,
    required this.label,
    required this.lineBefore,
    required this.lineAfter,
    this.ai = false,
  });
  final Widget child;
  final Color color;
  final String label;
  final bool lineBefore;
  final bool lineAfter;
  final bool ai;

  static const _node = 28.0;

  /// 띄어쓰기가 있는 이름은 단어 사이에서만 줄이 바뀌게 글자 사이를 붙여 둔다('서촌두에 뜨 / 라또리아' 방지).
  /// 띄어쓰기 없는 이름이 한 줄에 안 들어가면 글자 수 가운데에서 두 줄로 나눈다('더숲초소책 / 방' 대신 '더숲초 / 소책방')
  static String _breakName(String name, TextStyle style, double maxWidth, TextScaler scaler) {
    if (name.contains(' ')) {
      return name.split(' ').map((w) => w.runes.map(String.fromCharCode).join('⁠')).join(' ');
    }
    final painter = TextPainter(text: TextSpan(text: name, style: style), textDirection: TextDirection.ltr, textScaler: scaler, maxLines: 1)
      ..layout();
    final fits = painter.width <= maxWidth;
    painter.dispose();
    final chars = name.runes.map(String.fromCharCode).toList();
    if (fits || chars.length < 2) return name;
    final half = (chars.length + 1) ~/ 2;
    return '${chars.sublist(0, half).join()}\n${chars.sublist(half).join()}';
  }

  @override
  Widget build(BuildContext context) {
    Widget line(bool on) => Expanded(child: Container(height: 1, color: on ? AppColors.border : null));
    return Column(
      children: [
        SizedBox(
          height: _node,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Row(children: [line(lineBefore), const SizedBox(width: _node + 6), line(lineAfter)]),
              Container(width: _node, height: _node, alignment: Alignment.center, decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: child),
              if (ai)
                Transform.translate(
                  offset: const Offset(11, -11),
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(color: AppColors.ai, shape: BoxShape.circle, border: Border.all(color: AppColors.surface, width: 1.5)),
                    child: const Icon(Icons.auto_awesome, size: 8, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final style = AppTypography.meta.copyWith(color: AppColors.textPrimary, height: 1.35);
              final text = _breakName(label, style, constraints.maxWidth, MediaQuery.textScalerOf(context));
              return Text(text, style: style, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center);
            },
          ),
        ),
      ],
    );
  }
}

/// 날짜를 정하지 않은 코스 한 줄 (날짜 있는 다가오는 코스가 없을 때만, 누르면 코스 탭). 07 D58
class HomeUndatedCourses extends StatelessWidget {
  const HomeUndatedCourses({super.key, required this.courses, required this.onTap});
  final List<CourseSummary> courses;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(SectionCard.innerPadding, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(AppRadius.small)),
            child: const Icon(Icons.event_outlined, size: 20, color: AppColors.textSecondary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('날짜 미정 코스 ${courses.length}개', style: AppTypography.bodyStrong),
                Text(courses.map((c) => c.title).join(', '), style: AppTypography.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

/// 저장한 곳을 지역(구 · 시)으로 묶어 코스 만들기로 잇는다. 곳 수가 많은 지역부터 세 곳까지.
/// '코스 만들기'는 장소를 미리 고르지 않고 3단계를 그 지역으로 걸러 연다.
class HomeRegionGroups extends StatelessWidget {
  const HomeRegionGroups({super.key, required this.places, required this.onStart, required this.onOpenRegion});
  final List<Place> places;
  final ValueChanged<String> onStart;
  final ValueChanged<String> onOpenRegion;

  static List<(String, List<Place>)> groups(List<Place> places) {
    final map = <String, List<Place>>{};
    for (final p in places) {
      final d = p.district;
      if (d.isNotEmpty) map.putIfAbsent(d, () => []).add(p);
    }
    return [for (final e in map.entries) (e.key, e.value)]..sort((a, b) => b.$2.length.compareTo(a.$2.length));
  }

  @override
  Widget build(BuildContext context) {
    final list = groups(places).take(3).toList();
    return DividedRows(
      indent: SectionCard.innerPadding + 44 + AppSpacing.sm,
      children: [
        for (final (name, items) in list)
          InkWell(
            onTap: () => onOpenRegion(name),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(SectionCard.innerPadding, 10, AppSpacing.sm, 10),
              child: Row(
                children: [
                  CourseThumb(
                    course: CourseSummary(id: name, title: name, placeCount: items.length, stopCategoryKeys: [for (final p in items) p.categoryKey]),
                    size: 44,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$name ${items.length}곳', style: AppTypography.bodyStrong),
                        Text(items.take(3).map((p) => p.name).join(', '), style: AppTypography.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  // 작은 알약 버튼 (보이는 높이 32, 누르는 영역 44)
                  Semantics(
                    button: true,
                    label: '$name에서 코스 만들기',
                    excludeSemantics: true,
                    child: InkResponse(
                      onTap: () => onStart(name),
                      radius: 30,
                      child: SizedBox(
                        height: 44,
                        child: Center(
                          child: Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: AppRadius.pillAll),
                            child: Text('코스 만들기', style: AppTypography.label.copyWith(fontSize: 13, color: AppColors.primary)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 할 일 한 줄 (장소 저장 · 코스 만들기). 코스가 있을 때(③④)만 보여 준다.
class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({super.key, required this.onSavePlace, required this.onNewCourse});
  final VoidCallback onSavePlace;
  final VoidCallback onNewCourse;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.link_rounded,
            label: '장소 저장',
            iconColor: AppColors.primary,
            iconBackground: AppColors.primarySoft,
            onTap: onSavePlace,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _QuickAction(
            icon: Icons.route_rounded,
            label: '코스 만들기',
            iconColor: Colors.white,
            iconBackground: AppColors.primary,
            onTap: onNewCourse,
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.iconBackground,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final Color iconBackground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.thumb), side: const BorderSide(color: AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: iconBackground, borderRadius: BorderRadius.circular(AppRadius.small)),
                  child: Icon(icon, size: 17, color: iconColor),
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(child: Text(label, style: AppTypography.label, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 최근 저장한 곳 (가로 사진 줄). 출처 계정 이름은 응답에 없어 저장한 시점을 보여 준다.
class RecentSavedStrip extends StatelessWidget {
  const RecentSavedStrip({super.key, required this.items});
  final List<RecentExtraction> items;

  static const _tileWidth = 96.0;
  static const _tileHeight = 128.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _tileHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: SectionCard.innerPadding),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (_, i) {
          final item = items[i];
          return _PhotoTile(
            place: item.place,
            width: _tileWidth,
            height: _tileHeight,
            caption: formatRecentDate(item.extractedAt),
            onTap: () => context.push(AppRoutes.place(item.place.id)),
          );
        },
      ),
    );
  }
}

/// 이런 코스는 어때요? (서버 추천 코스, 가로 카드)
class SuggestedCourseStrip extends StatelessWidget {
  const SuggestedCourseStrip({super.key, required this.courses, required this.onTap});
  final List<SuggestedCourse> courses;
  final ValueChanged<SuggestedCourse> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 158,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: SectionCard.innerPadding),
        itemCount: courses.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (_, i) {
          final course = courses[i];
          return SizedBox(
            width: 200,
            child: Material(
              color: AppColors.surfaceRaised,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.medium), side: const BorderSide(color: AppColors.border)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onTap(course),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppNetworkImage(url: course.imageUrl, width: 200, height: 96, radius: 0, placeholderIcon: Icons.route_rounded),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, AppSpacing.xs, 10, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(course.title, style: AppTypography.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(
                            ['${course.placeCount}곳', if (course.durationLabel != null) course.durationLabel!].join(' · '),
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 지금 뜨는 장소 (2×2 사진 타일). 저장 여부는 북마크 표시로만 보여 준다.
class TrendingPlaceGrid extends StatelessWidget {
  const TrendingPlaceGrid({super.key, required this.places});
  final List<Place> places;

  @override
  Widget build(BuildContext context) {
    final shown = places.take(4).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SectionCard.innerPadding),
      child: LayoutBuilder(
        builder: (context, box) {
          final size = (box.maxWidth - AppSpacing.xs) / 2;
          return Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final p in shown)
                _PhotoTile(
                  place: p,
                  width: size,
                  height: size,
                  caption: p.categoryLabel,
                  saved: p.isSaved,
                  onTap: () => context.push(AppRoutes.place(p.id)),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// 사진 타일: 사진이 있으면 아래쪽 어둡게 + 흰 글자, 없으면 카테고리 색 칸 + 아이콘 + 진한 글자.
class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.place,
    required this.width,
    required this.height,
    required this.caption,
    required this.onTap,
    this.saved,
  });

  final Place place;
  final double width;
  final double height;
  final String caption;
  final VoidCallback onTap;

  /// null이면 북마크 표시를 하지 않는다
  final bool? saved;

  @override
  Widget build(BuildContext context) {
    final hasImage = place.imageUrl != null && place.imageUrl!.isNotEmpty;
    final textColor = hasImage ? Colors.white : AppColors.textPrimary;
    return Semantics(
      button: true,
      label: '${place.name}, $caption',
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.thumb),
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PlaceImage(place: place, width: width, height: height, radius: 0, iconSize: 26, iconAlignment: const Alignment(0, -0.25)),
                if (hasImage)
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.45, 1],
                        colors: [AppColors.photoScrimClear, AppColors.photoScrim],
                      ),
                    ),
                  ),
                if (saved != null)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(color: AppColors.photoBadge, borderRadius: BorderRadius.circular(AppRadius.small)),
                      child: Icon(saved! ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, size: 15, color: Colors.white),
                    ),
                  ),
                Positioned(
                  left: 8,
                  right: 6,
                  bottom: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        style: AppTypography.label.copyWith(color: textColor, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        caption,
                        style: AppTypography.caption.copyWith(color: hasImage ? Colors.white.withValues(alpha: 0.88) : AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
