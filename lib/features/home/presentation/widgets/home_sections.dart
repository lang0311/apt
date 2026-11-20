import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/station_steps.dart';
import '../../../../core/widgets/surfaces.dart';
import '../../../course/domain/course_models.dart';
import '../../../course/presentation/widgets/course_thumb.dart';
import '../../../extraction/domain/extraction_models.dart';
import '../../../place/domain/place.dart';
import '../../../saved/presentation/widgets/place_image.dart';

/// ① 처음 써요 — 공유로 저장하는 3단계 + 링크 붙여넣기
class HomeStartGuide extends StatelessWidget {
  const HomeStartGuide({super.key, required this.onPasteLink});
  final VoidCallback onPasteLink;

  @override
  Widget build(BuildContext context) {
    // v2: 채움 판 하나에 제목 · 정거장 세 개 · 링크 붙여넣기
    return Container(
      decoration: BoxDecoration(color: AppColors.fill, borderRadius: BorderRadius.circular(22)),
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 22, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('릴스에서 본 곳,\n바로 저장해 보세요', style: AppTypography.section.copyWith(fontSize: 20)),
          const SizedBox(height: 18),
          const StationSteps(gap: 14, steps: [('릴스에서 ⋯ 누르기', null), ('공유 → APT 고르기', null), ('찾은 장소 저장', null)]),
          const SizedBox(height: AppSpacing.lg),
          AppButton(label: '링크 붙여넣기', height: 48, onPressed: onPasteLink),
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
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardAll,
        side: const BorderSide(color: AppColors.border),
      ),
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

/// ③ 다가오는 코스 / ④ 오늘 코스 (리디자인 v2): 연파랑 카드. D-day(또는 '오늘')를 크게, 아래 날짜 · 출발 → 이름 → 번호 노선 →
/// 아래 줄 'n곳 · 직선 거리'와 '코스 보기'. 파티면 오른쪽 위 '함께 n명'. 서버가 장소 이름을 주지 않으면 노선 대신 모자이크.
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
    final hasStops = course.stopNames.length == course.stopCategoryKeys.length && course.stopNames.isNotEmpty;
    final dday = AppTypography.display.copyWith(
      fontSize: 34,
      height: 1,
      color: AppColors.primary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final Widget headline;
    if (isToday) {
      headline = Text('오늘', style: dday);
    } else if (date == null) {
      headline = Text('날짜 미정', style: AppTypography.section.copyWith(color: AppColors.textSecondary, height: 1.1));
    } else {
      headline = Text(ddayLabel(date), style: dday);
    }
    final when = [
      if (date != null) formatMonthDayWeekday(date),
      if (course.startTime != null) '${formatTimeOfDay(course.startTime!)} 출발',
    ].join(' · ');
    final foot = [
      '${course.placeCount}곳',
      if (course.distanceKm != null) '직선 ${formatDistance((course.distanceKm! * 1000).round())}',
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: AppColors.primarySoft,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: headline),
                      if (course.isParty)
                        Container(
                          height: 28,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.pillAll),
                          child: Text('함께 ${course.memberCount}명', style: AppTypography.label.copyWith(color: AppColors.textSecondary)),
                        ),
                    ],
                  ),
                  if (when.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      when,
                      style: AppTypography.meta.copyWith(color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(course.title, style: AppTypography.section.copyWith(fontSize: 20), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 18),
                  if (hasStops)
                    _StopStrip(keys: course.stopCategoryKeys, names: course.stopNames, isAi: course.stopIsAi)
                  else
                    Align(
                      alignment: Alignment.centerLeft,
                      child: CourseThumb(course: course, size: 72),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  const Divider(height: 1, color: Color(0xFFD6E3FE)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(foot, style: AppTypography.meta.copyWith(color: AppColors.textSecondary)),
                      ),
                      Text('코스 보기', style: AppTypography.label.copyWith(color: AppColors.primary)),
                      const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.primary),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!isToday && moreCount > 0)
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: onMore,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 8, 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('다가오는 코스 $moreCount개 더', style: AppTypography.meta),
                    const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textTertiary),
                  ],
                ),
              ),
            ),
          ),
      ],
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
      final ai = i < isAi.length && isAi[i];
      // v2: 업종 아이콘 대신 순서 번호. 내가 고른 곳은 파랑, AI 추천은 주황 + ✦
      return _StripCell(
        lineBefore: !first,
        lineAfter: !last,
        color: ai ? AppColors.ai : AppColors.primary,
        ai: ai,
        label: names[i],
        child: Text(
          '${i + 1}',
          style: AppTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700, height: 1),
        ),
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

  static const _node = 20.0;

  /// 띄어쓰기가 있는 이름은 단어 사이에서만 줄이 바뀌게 글자 사이를 붙여 둔다('서촌두에 뜨 / 라또리아' 방지).
  /// 띄어쓰기 없는 이름이 한 줄에 안 들어가면 글자 수 가운데에서 두 줄로 나눈다('더숲초소책 / 방' 대신 '더숲초 / 소책방')
  static String _breakName(String name, TextStyle style, double maxWidth, TextScaler scaler) {
    if (name.contains(' ')) {
      return name.split(' ').map((w) => w.runes.map(String.fromCharCode).join('⁠')).join(' ');
    }
    final painter = TextPainter(
      text: TextSpan(text: name, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final fits = painter.width <= maxWidth;
    painter.dispose();
    final chars = name.runes.map(String.fromCharCode).toList();
    if (fits || chars.length < 2) return name;
    final half = (chars.length + 1) ~/ 2;
    return '${chars.sublist(0, half).join()}\n${chars.sublist(half).join()}';
  }

  @override
  Widget build(BuildContext context) {
    Widget line(bool on) => Expanded(child: Container(height: 2, color: on ? const Color(0xFFC5D7FE) : null));
    return Column(
      children: [
        SizedBox(
          height: _node,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Row(
                children: [
                  line(lineBefore),
                  const SizedBox(width: _node),
                  line(lineAfter),
                ],
              ),
              Container(
                width: _node,
                height: _node,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: child,
              ),
              if (ai)
                Transform.translate(
                  offset: const Offset(10, -9),
                  child: Text('✦', style: AppTypography.caption.copyWith(color: AppColors.aiText, fontSize: 10, height: 1)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final style = AppTypography.caption.copyWith(color: AppColors.textSecondary, height: 1.3);
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
                    course: CourseSummary(
                      id: name,
                      title: name,
                      placeCount: items.length,
                      stopCategoryKeys: [for (final p in items) p.categoryKey],
                    ),
                    size: 44,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$name ${items.length}곳', style: AppTypography.bodyStrong),
                        Text(
                          items.take(3).map((p) => p.name).join(', '),
                          style: AppTypography.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
                            child: Text('코스 만들기', style: AppTypography.label.copyWith(color: AppColors.primary)),
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
            iconColor: AppColors.textPrimary,
            iconBackground: AppColors.primarySoft,
            onTap: onSavePlace,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _QuickAction(
            icon: Icons.route_rounded,
            label: '코스 만들기',
            iconColor: AppColors.primary,
            iconBackground: AppColors.primary,
            onTap: onNewCourse,
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.iconColor, required this.iconBackground, required this.onTap});

  final IconData icon;
  final String label;
  final Color iconColor;

  /// v2에서는 칸 바탕을 채움색 하나로 통일해서 쓰지 않는다 (호출부 호환용으로 남김)
  final Color iconBackground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // v2: 채움 칸, 위 아이콘 · 아래 굵은 이름
    return Material(
      color: AppColors.fill,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(height: 18),
              Text(label, style: AppTypography.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
                side: const BorderSide(color: AppColors.border),
              ),
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
                        style: AppTypography.label.copyWith(color: textColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        caption,
                        style: AppTypography.caption.copyWith(color: hasImage ? AppColors.onPhotoMuted : AppColors.textSecondary),
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
