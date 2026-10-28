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
import '../widgets/course_share_sheet.dart';
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
                data: (c) => justSaved && c.isParty && c.partyId != null
                    ? _ShareAfterSave(course: c, child: _Body(course: c, justSaved: true))
                    : _Body(course: c, justSaved: justSaved),
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
    final date = course.date;
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        CourseHero(
          title: course.title,
          meta: courseMetaLine(date: course.date, start: course.startTime, placeCount: course.stops.length, duration: course.totalDuration),
          dday: date != null && daysUntil(date) >= 0 ? ddayLabel(date) : null,
          savedNotice: justSaved,
        ),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (course.isParty) ...[
                _CrewStrip(course: course),
                const SizedBox(height: AppSpacing.xs),
              ],
              CourseRouteMap(stops: course.stops, height: course.isParty ? 120 : 160),
              const SizedBox(height: AppSpacing.sm),
              SectionCard(
                title: '일정',
                trailing: course.canEdit ? CourseEditButton(onPressed: () => context.push(AppRoutes.courseEdit(course.id))) : null,
                child: CourseTimeline(
                  stops: course.stops,
                  onTapStop: (s) => context.push(AppRoutes.place(s.place.id)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 파티 코스를 저장하고 들어오면 파티원에게 알릴지 한 번 묻는다
class _ShareAfterSave extends ConsumerStatefulWidget {
  const _ShareAfterSave({required this.course, required this.child});
  final Course course;
  final Widget child;

  @override
  ConsumerState<_ShareAfterSave> createState() => _ShareAfterSaveState();
}

class _ShareAfterSaveState extends ConsumerState<_ShareAfterSave> {
  @override
  void initState() {
    super.initState();
    _ask();
  }

  Future<void> _ask() async {
    List<PartyMember>? members;
    try {
      members = (await ref.read(partyProvider(widget.course.partyId!).future)).members;
    } catch (_) {} // 파티원 이름을 못 불러와도 묻는다
    if (!mounted) return;
    // 혼자 남은 새 파티면 알릴 사람이 없다
    if (members != null && members.every((m) => m.isMe)) return;
    await showCourseShareSheet(context, course: widget.course, members: members, afterSave: true);
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
    final names = members == null ? '파티 ${course.memberCount}명' : members.crewNames;
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
                  PartyAvatarStack(members: members, size: 24, max: 3, overlap: true),
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
            for (final (i, m) in members.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    PartyAvatarStack(members: [m], size: 36, max: 1, colorOffset: i),
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
            if (members.any((m) => !m.isMe))
              TextButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  showCourseShareSheet(context, course: course, members: members);
                },
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('코스 알리기'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary, alignment: Alignment.centerLeft, minimumSize: const Size(44, 48)),
              ),
          ],
        ),
      ),
    );
  }
}
