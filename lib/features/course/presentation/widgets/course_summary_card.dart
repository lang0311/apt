import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/surfaces.dart';
import '../../../party/domain/party_models.dart';
import '../../../party/presentation/widgets/party_avatar_stack.dart';
import '../../domain/course_models.dart';

/// 코스 목록 행 (SectionCard 안 구분선 행): 사진 · 이름 · (파티원 한 줄) · 지역 · n곳 · 오른쪽 날짜
class CourseSummaryRow extends StatelessWidget {
  const CourseSummaryRow({super.key, required this.course, required this.onTap, this.now});
  final CourseSummary course;
  final VoidCallback onTap;

  /// 테스트용 기준 날짜
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final c = course;
    final where = [?c.regionLabel, '${c.placeCount}곳'].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SectionCard.innerPadding, vertical: 10),
        child: Row(
          children: [
            AppNetworkImage(url: c.thumbnailUrl, width: 48, height: 48, radius: 12),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 이름은 두 줄까지, 파티원·지역 줄은 한 줄로 줄인다
                  Text(c.title, style: AppTypography.bodyStrong, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (c.isParty) ...[
                    const SizedBox(height: 3),
                    _People(names: c.memberNames, count: c.memberCount),
                  ],
                  const SizedBox(height: 2),
                  Text(where, style: AppTypography.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            if (c.date != null) _When(date: c.date!, now: now),
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
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            shown,
            style: AppTypography.caption.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// 오른쪽 날짜: 다가오는 코스 = D-day(파랑) + "11.02 월", 지난 코스 = 회색 "10.12" + "일요일"
class _When extends StatelessWidget {
  const _When({required this.date, this.now});
  final DateTime date;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final mmdd = '${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    final upcoming = daysUntil(date, now: now) >= 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: upcoming
          ? [
              Text(ddayLabel(date, now: now), style: AppTypography.label.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('$mmdd ${weekdayLabel(date)}', style: AppTypography.caption),
            ]
          : [
              Text(mmdd, style: AppTypography.label.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text('${weekdayLabel(date)}요일', style: AppTypography.caption),
            ],
    );
  }
}
