import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../saved/presentation/widgets/category_style.dart';
import '../../domain/course_models.dart';

/// 코스 목록 · 홈 카드의 앞 칸. 코스 사진이 오면 사진을, 안 오면 코스 안 장소의
/// 카테고리 아이콘을 모아 보여 준다 (코스마다 모양이 달라 목록에서 구분된다). 곳 수에 따라 칸 나누기가 바뀐다.
class CourseThumb extends StatelessWidget {
  const CourseThumb({super.key, required this.course, this.size = 48});
  final CourseSummary course;
  final double size;

  static const _gap = 3.0;

  @override
  Widget build(BuildContext context) {
    final url = course.thumbnailUrl;
    final keys = course.stopCategoryKeys;
    if ((url != null && url.isNotEmpty) || keys.isEmpty) {
      return AppNetworkImage(url: url, width: size, height: size, radius: size >= 60 ? AppRadius.thumb : 12, placeholderIcon: Icons.route_rounded);
    }
    final half = (size - _gap) / 2;
    Widget tile(String key, double w, double h) {
      final style = CategoryStyle.of(key);
      return Container(
        width: w,
        height: h,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: style.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.tiny)),
        child: Icon(style.icon, size: (w < h ? w : h) * 0.56, color: style.ink),
      );
    }

    // 곳 수에 따라 칸을 나눈다: 1곳 한 칸 · 2곳 반반 · 3곳 큰 칸 + 둘 · 4곳 2×2 · 5곳부터 셋 + 남은 수
    final n = keys.length;
    final Widget mosaic;
    if (n == 1) {
      mosaic = tile(keys[0], size, size);
    } else if (n == 2) {
      mosaic = Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [tile(keys[0], half, size), tile(keys[1], half, size)]);
    } else if (n == 3) {
      mosaic = Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          tile(keys[0], half, size),
          Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [tile(keys[1], half, half), tile(keys[2], half, half)]),
        ],
      );
    } else {
      final fourth = n == 4
          ? tile(keys[3], half, half)
          : Container(
              width: half,
              height: half,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(AppRadius.tiny)),
              child: Text('+${n - 3}', style: TextStyle(fontSize: half * 0.36, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
            );
      mosaic = Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [tile(keys[0], half, half), tile(keys[1], half, half)]),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [tile(keys[2], half, half), fourth]),
        ],
      );
    }

    // 카테고리 아이콘은 장식이라 스크린리더에는 읽히지 않게 한다 (코스 이름 · 곳 수가 이미 읽힌다)
    return ExcludeSemantics(child: SizedBox(width: size, height: size, child: mosaic));
  }
}
