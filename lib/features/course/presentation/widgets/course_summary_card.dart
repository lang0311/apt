import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/surfaces.dart';
import '../../../party/domain/party_models.dart';
import '../../../party/presentation/widgets/party_avatar_stack.dart';
import '../../domain/course_models.dart';
import 'course_thumb.dart';

/// 코스 목록 행 (v2): 사진 · 이름 · (파티원 한 줄) · 지역 · n곳 (지난 코스는 · 날짜) · 오른쪽 D-day(다가오는 코스만)
class CourseSummaryRow extends StatelessWidget {
  const CourseSummaryRow({super.key, required this.course, required this.onTap});
  final CourseSummary course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final past = course.date != null && daysUntil(course.date!) < 0;
    final where = [?course.regionLabel, '${course.placeCount}곳', if (past) '${course.date!.month}월 ${course.date!.day}일'].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SectionCard.innerPadding, vertical: 10),
        child: Row(
          children: [
            CourseThumb(course: course),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 이름은 두 줄까지, 파티원·지역 줄은 한 줄로 줄인다
                  Text(course.title, style: AppTypography.bodyStrong, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (course.isParty) ...[const SizedBox(height: 3), _People(names: course.memberNames, count: course.memberCount)],
                  const SizedBox(height: 2),
                  Text(where, style: AppTypography.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (!past) ...[const SizedBox(width: AppSpacing.xs), _When(date: course.date)],
          ],
        ),
      ),
    );
  }
}

/// 파티원 한 줄: 얼굴 최대 3개 + 이름(넘치면 "외 n명"). 절대 두 줄로 넘치지 않는다.
class _People extends StatelessWidget {
  const _People({required this.names, required this.count});
  final List<String> names;
  final int count;

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) return Text('$count명', style: AppTypography.caption.copyWith(color: AppColors.textPrimary));
    final shown = names.length > 3 ? '${names.take(2).join(', ')} 외 ${names.length - 2}명' : names.join(', ');
    return Row(
      children: [
        PartyAvatarStack(
          members: [for (final (i, n) in names.take(3).indexed) PartyMember(id: '$i', nickname: n, isMe: n == '나')],
          size: 20,
          max: 3,
          overlap: true,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            shown,
            style: AppTypography.caption.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// 오른쪽 날짜: 다가오는 코스 = D-day(파랑) + "11월 15일 (일)", 지난 코스 = 회색 "10월 26일 (월)" 한 줄.
/// 날짜 표기는 앱 전체에서 "11월 13일 (금)" 한 가지로 맞춘다 (UI 리뷰 10)
class _When extends StatelessWidget {
  const _When({required this.date});
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.bodyStrong.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    if (date == null) return Text('날짜 미정', style: style.copyWith(color: AppColors.textTertiary));
    return Text(ddayLabel(date!), style: style.copyWith(color: AppColors.primary));
  }
}
