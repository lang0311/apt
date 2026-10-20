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
import '../../../extraction/domain/extraction_models.dart';
import '../../../place/domain/place.dart';
import '../../../saved/presentation/widgets/place_image.dart';

/// 홈 맨 위 카드 공통 테두리 (surface + border, radius 20)
BoxDecoration _topCardDecoration() => BoxDecoration(
      color: AppColors.surface,
      borderRadius: AppRadius.cardAll,
      border: Border.all(color: AppColors.border),
    );

/// ① 처음 써요 — 공유로 저장하는 3단계 + 링크 붙여넣기
class HomeStartGuide extends StatelessWidget {
  const HomeStartGuide({super.key, required this.onPasteLink});
  final VoidCallback onPasteLink;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _topCardDecoration(),
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs, horizontal: AppSpacing.xxs),
      decoration: BoxDecoration(color: AppColors.surfaceRaised, borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Column(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: appMark ? AppColors.ink : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: appMark
                ? Text('APT', style: AppTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10))
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
                          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
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

/// ③ 다가오는 코스 / ④ 오늘 코스. D-day(또는 '오늘')만 크게, 이름과 '날짜 · 장소 수', 대표 사진 1장.
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
    final meta = '${date == null ? '날짜 미정' : formatMonthDayWeekday(date)} · ${course.placeCount}곳';
    final big = AppTypography.title.copyWith(fontSize: 22, fontWeight: FontWeight.w800, height: 1.1);

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
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 14, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isToday)
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              Text('오늘', style: big.copyWith(color: AppColors.primary)),
                            ],
                          )
                        else
                          Text(
                            date == null ? '날짜 미정' : ddayLabel(date),
                            style: date == null ? big.copyWith(fontSize: 18, color: AppColors.textSecondary) : big.copyWith(color: AppColors.primary),
                          ),
                        const SizedBox(height: 6),
                        Text(course.title, style: AppTypography.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(meta, style: AppTypography.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppNetworkImage(url: course.thumbnailUrl, width: 60, height: 60, radius: AppRadius.thumb, placeholderIcon: Icons.route_rounded),
                ],
              ),
            ),
          ),
          if (isToday)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, 14, 14),
              child: AppButton(label: '코스 보기', height: 44, onPressed: onOpen),
            )
          else if (moreCount > 0) ...[
            const Divider(height: 1, color: AppColors.border),
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
            iconBackground: AppColors.ink,
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
                  decoration: BoxDecoration(color: iconBackground, borderRadius: BorderRadius.circular(10)),
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

  static const _w = 96.0;
  static const _h = 128.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: SectionCard.innerPadding),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (_, i) {
          final item = items[i];
          return _PhotoTile(
            place: item.place,
            width: _w,
            height: _h,
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
          final c = courses[i];
          return SizedBox(
            width: 200,
            child: Material(
              color: AppColors.surfaceRaised,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onTap(c),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppNetworkImage(url: c.imageUrl, width: 200, height: 96, radius: 0, placeholderIcon: Icons.route_rounded),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, AppSpacing.xs, 10, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.title, style: AppTypography.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(
                            ['${c.placeCount}곳', if (c.durationLabel != null) c.durationLabel!].join(' · '),
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
    final fg = hasImage ? Colors.white : AppColors.textPrimary;
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
                        colors: [Color(0x0014223A), Color(0xB314223A)],
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
                      decoration: BoxDecoration(color: const Color(0x7314223A), borderRadius: BorderRadius.circular(9)),
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
                        style: AppTypography.label.copyWith(color: fg, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        caption,
                        style: AppTypography.caption.copyWith(color: hasImage ? Colors.white.withValues(alpha: 0.88) : AppColors.textSecondary, fontSize: 10),
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
