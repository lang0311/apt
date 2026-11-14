import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../saved/presentation/widgets/category_style.dart';
import '../../domain/course_models.dart';

/// 코스 목록 · 홈 카드의 앞 칸. 코스 사진이 오면 사진을, 안 오면 코스 안 장소의
/// 카테고리 아이콘을 2×2로 모아 보여 준다 (코스마다 모양이 달라 목록에서 구분된다).
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
    final cell = (size - _gap) / 2;
    Widget cellAt(int i) {
      if (i >= keys.length) {
        return Container(width: cell, height: cell, decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(7)));
      }
      final style = CategoryStyle.of(keys[i]);
      return Container(
        width: cell,
        height: cell,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: style.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
        child: Icon(style.icon, size: cell * 0.56, color: style.color),
      );
    }

    // 카테고리 아이콘은 장식이라 스크린리더에는 읽히지 않게 한다 (코스 이름 · 곳 수가 이미 읽힌다)
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [cellAt(0), cellAt(1)]),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [cellAt(2), cellAt(3)]),
          ],
        ),
      ),
    );
  }
}
