import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/headers.dart';
import '../../../../core/widgets/overlays.dart';
import '../../../../core/widgets/states.dart';
import '../../../../core/widgets/surfaces.dart';
import '../../../party/domain/party_models.dart';
import '../../../party/presentation/party_providers.dart';
import '../../../party/presentation/widgets/invite_modal.dart';
import '../../../party/presentation/widgets/party_avatar_stack.dart';
import '../../domain/course_models.dart';
import '../course_providers.dart';
import '../widgets/course_route_map.dart';
import '../widgets/course_timeline.dart';

/// #32 코스 상세 (보는 상태). 고치기는 일정 카드의 "편집" 하나로 들어간다(코스 편집 화면).
class CourseDetailPage extends ConsumerWidget {
  const CourseDetailPage({super.key, required this.courseId, this.justSaved = false});
  final String courseId;

  /// 코스를 저장하고 바로 들어왔을 때 "코스가 저장되었어요"를 보여 준다
  final bool justSaved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = ref.watch(courseDetailProvider(courseId));
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            PlainHeader(
              onLeading: () => context.canPop() ? context.pop() : context.go(AppRoutes.courses),
              actions: [
                IconButton(
                  tooltip: '코스 메뉴',
                  icon: const Icon(Icons.more_horiz_rounded, color: AppColors.textPrimary),
                  // 이름·날짜 수정, 공유, 삭제 — NEEDS BACKEND (docs/07 §3)
                  onPressed: () => showAppSnackBar(context, '코스 관리 메뉴는 준비 중이에요.'),
                ),
              ],
            ),
            Expanded(
              child: AsyncValueView<Course>(
                value: course,
                onRetry: () => ref.invalidate(courseDetailProvider(courseId)),
                data: (c) => _Body(course: c, justSaved: justSaved),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.course, required this.justSaved});
  final Course course;
  final bool justSaved;

  @override
  Widget build(BuildContext context) {
    final c = course;
    final days = c.date == null ? null : daysUntil(c.date!);
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        CourseHero(
          title: c.title,
          meta: courseMetaLine(date: c.date, start: c.startTime, placeCount: c.stops.length, duration: c.totalDuration),
          dday: days != null && days >= 0 ? ddayLabel(c.date!) : null,
          savedNotice: justSaved,
        ),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (c.isParty) ...[
                _CrewStrip(course: c),
                const SizedBox(height: AppSpacing.xs),
              ],
              CourseRouteMap(stops: c.stops, height: c.isParty ? 120 : 160),
              const SizedBox(height: AppSpacing.sm),
              SectionCard(
                title: '일정',
                trailing: c.canEdit ? CourseEditButton(onPressed: () => context.push(AppRoutes.courseEdit(c.id))) : null,
                child: CourseTimeline(
                  stops: c.stops,
                  onTapStop: (s, _) => context.push(AppRoutes.place(s.place.id)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 파티원 한 줄 띠: 얼굴 묶음 + 이름. 누르면 파티원 시트(목록 + 초대).
class _CrewStrip extends ConsumerWidget {
  const _CrewStrip({required this.course});
  final Course course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partyId = course.partyId;
    // NEEDS BACKEND: 코스 상세에 파티원 목록이 같이 오는지, 파티 API를 따로 부르는지
    final members = partyId == null ? null : ref.watch(partyProvider(partyId)).value?.members;
    final names = members == null ? '파티 ${course.memberCount}명' : _names(members);
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: members == null ? null : () => _showMembers(context, members, partyId!),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              children: [
                if (members != null) ...[
                  PartyAvatarStack(members: members, size: 24, max: 3),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Expanded(child: Text(names, style: AppTypography.label, maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (members != null) const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 한 줄을 넘지 않게: 세 명까지 이름, 넘치면 "외 n명"
  static String _names(List<PartyMember> m) {
    final shown = [for (final x in m.take(3)) x.isMe ? '나' : x.nickname];
    return m.length > 3 ? '${shown.take(2).join(', ')} 외 ${m.length - 2}명' : shown.join(', ');
  }

  void _showMembers(BuildContext context, List<PartyMember> members, String partyId) {
    showAppBottomSheet<void>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xxs, AppSpacing.screenH, AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('함께하는 사람 ${members.length}명', style: AppTypography.cardTitle),
            const SizedBox(height: AppSpacing.xs),
            for (final m in members)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    PartyAvatarStack(members: [m], size: 36, max: 1),
                    const SizedBox(width: AppSpacing.sm),
                    Text(m.isMe ? '${m.nickname} (나)' : m.nickname, style: AppTypography.bodyStrong),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.xs),
            TextButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                showInviteModal(context, partyId: partyId);
              },
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('초대하기'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary, alignment: Alignment.centerLeft, minimumSize: const Size(44, 48)),
            ),
          ],
        ),
      ),
    );
  }
}
