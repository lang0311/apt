import 'package:flutter/material.dart';
import 'package:apt/core/widgets/spark_icon.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../saved/presentation/widgets/place_image.dart';
import '../../domain/course_models.dart';

/// "이 코스에 담긴 곳" — 일정 카드 아래 가로 사진 줄 (리디자인 v2 #30 아래쪽).
/// 사진(없으면 업종 색 칸) 아래 이름과 출처(내가 고른 곳 / ✦ AI 추천).
class CoursePlacesStrip extends StatelessWidget {
  const CoursePlacesStrip({super.key, required this.stops, this.onTap});

  final List<CourseStop> stops;
  final void Function(CourseStop stop)? onTap;

  static const _w = 120.0;
  static const _h = 88.0;

  @override
  Widget build(BuildContext context) {
    if (stops.isEmpty) return const SizedBox.shrink();
    final textH = MediaQuery.textScalerOf(context).scale(40);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: AppSpacing.screenPadding,
          child: Text('이 코스에 담긴 곳', style: AppTypography.cardTitle),
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: _h + 6 + textH,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: AppSpacing.screenPadding,
            itemCount: stops.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs + 2),
            itemBuilder: (_, i) {
              final s = stops[i];
              final from = s.isAi ? 'AI 추천' : '내가 고른 곳';
              return Semantics(
                button: onTap != null,
                label: '${s.place.name}, $from',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: onTap == null ? null : () => onTap!(s),
                  child: SizedBox(
                    width: _w,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PlaceImage(place: s.place, width: _w, height: _h, radius: AppRadius.medium, iconSize: 24),
                        const SizedBox(height: 6),
                        Text(s.place.name, style: AppTypography.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                        s.isAi
                            ? Text.rich(
                                TextSpan(
                                  children: [
                                    const WidgetSpan(
                                      alignment: PlaceholderAlignment.middle,
                                      child: Padding(
                                        padding: EdgeInsets.only(right: 3),
                                        child: SparkIcon(size: 12, color: AppColors.aiText),
                                      ),
                                    ),
                                    TextSpan(text: from),
                                  ],
                                ),
                                style: AppTypography.caption.copyWith(color: AppColors.aiText),
                                maxLines: 1,
                              )
                            : Text(from, style: AppTypography.caption, maxLines: 1),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
