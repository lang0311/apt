import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di/repositories.dart';
import '../../../app/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/share/pending_links.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/bottom_cta.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/headers.dart';
import '../../../core/widgets/overlays.dart';
import '../../../core/widgets/states.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../course/presentation/course_providers.dart';
import '../domain/party_models.dart';
import 'party_providers.dart';

/// #28 초대 수락. 미로그인이면 토큰을 보관하고 로그인으로 보낸 뒤, 로그인 후 이 화면으로 돌아온다.
class InviteAcceptPage extends ConsumerStatefulWidget {
  const InviteAcceptPage({super.key, required this.token});
  final String token;

  @override
  ConsumerState<InviteAcceptPage> createState() => _InviteAcceptPageState();
}

class _InviteAcceptPageState extends ConsumerState<InviteAcceptPage> {
  bool _sharePreferences = true;
  bool _submitting = false;

  bool get _signedIn => ref.read(authControllerProvider).status == AuthStatus.authenticated;

  @override
  void initState() {
    super.initState();
    if (!_signedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(pendingLinksProvider.notifier).setInvite(widget.token);
        if (mounted) context.go(AppRoutes.login);
      });
    }
  }

  Future<void> _accept() async {
    setState(() => _submitting = true);
    try {
      await ref.read(partyRepositoryProvider).acceptInvitation(widget.token, shareMyPreferences: _sharePreferences);
      invalidateCourseData(ref);
      if (mounted) {
        showAppSnackBar(context, '코스에 참여했어요. 모임/파티 코스에서 확인할 수 있어요.');
        context.go(AppRoutes.courses);
      }
    } on InviteFailure catch (e) {
      if (mounted) showAppSnackBar(context, e.kind.title);
    } catch (e) {
      if (mounted) showAppSnackBar(context, failureMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _decline() async {
    try {
      await ref.read(partyRepositoryProvider).declineInvitation(widget.token);
    } catch (_) {
      // 거절 실패는 사용자 흐름을 막지 않는다
    }
    if (mounted) context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    if (!_signedIn) return const Scaffold(body: AppLoading());
    final invitation = ref.watch(invitationProvider(widget.token));
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PlainHeader(leadingIcon: LucideIcons.x, leadingTooltip: '닫기', onLeading: () => context.go(AppRoutes.home)),
            Expanded(
              child: invitation.when(loading: () => const AppLoading(), error: (e, _) => _error(e), data: _content),
            ),
            if (invitation.hasValue)
              BottomCta(
                child: Column(
                  children: [
                    AppButton(label: '코스에 참여하기', loading: _submitting, onPressed: _accept),
                    const SizedBox(height: AppSpacing.xs),
                    AppTextLink(label: '참여하지 않기', color: AppColors.textSecondary, onPressed: _submitting ? null : _decline),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 초대 예외(만료·이미 참여·인원 초과)는 디자인 없음 → 공통 빈 상태로 임시 구현
  Widget _error(Object error) {
    if (error is! InviteFailure) {
      return AppErrorState(error: error, onRetry: () => ref.invalidate(invitationProvider(widget.token)));
    }
    final alreadyJoined = error.kind == InviteFailureKind.alreadyJoined;
    return Center(
      child: AppEmptyState(
        icon: LucideIcons.mail,
        title: error.kind.title,
        description: error.kind.description,
        actionLabel: alreadyJoined ? '코스 목록 보기' : '홈으로',
        onAction: () => context.go(alreadyJoined ? AppRoutes.courses : AppRoutes.home),
      ),
    );
  }

  /// v2 "28 초대 수락": 보낸 사람 얼굴 · 큰 제목 → 채움 판(코스 이름 · 인원 · 고른 장소 번호 목록) → 취향 반영 스위치 행
  Widget _content(Invitation inv) {
    final name = inv.inviterName;
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xxs, AppSpacing.screenH, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  // v2: 파티원 얼굴 색(코랄) 채움 원 + 흰 첫 글자 (초대한 사람)
                  decoration: const BoxDecoration(color: AppColors.avatarCoral, shape: BoxShape.circle),
                  child: Text(
                    name.isEmpty ? '?' : name.characters.first,
                    style: AppTypography.bodyStrong.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text('$name님이 코스에\n초대했어요', style: AppTypography.display),
              const SizedBox(height: 6),
              // 초대된 파티원도 장소를 추가·편집할 수 있다 (07 D23)
              Text('참여하면 같이 장소를 고르고 코스를 고칠 수 있어요.', style: AppTypography.bodyMuted),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(AppSpacing.screenH, 22, AppSpacing.screenH, 0),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(color: AppColors.fill, borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(inv.courseTitle, style: AppTypography.cardTitle),
              const SizedBox(height: 2),
              Text([if (inv.courseDate != null) formatMonthDayWeekday(inv.courseDate!), '${inv.memberCount}명 참여 중'].join(' · '), style: AppTypography.meta),
              // 서버는 장소 이름 목록만 준다(장소별 사진 없음)
              if (inv.previewPlaceNames.isNotEmpty) ...[
                const SizedBox(height: 14),
                for (final (i, place) in inv.previewPlaceNames.indexed)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: AppColors.ink, shape: BoxShape.circle),
                          child: Text(
                            '${i + 1}',
                            style: AppTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(place, style: AppTypography.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                if (inv.selectedPlaceCount > inv.previewPlaceNames.length) ...[
                  const SizedBox(height: 10),
                  Text('외 ${inv.selectedPlaceCount - inv.previewPlaceNames.length}곳', style: AppTypography.meta),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        MergeSemantics(
          child: InkWell(
            onTap: () => setState(() => _sharePreferences = !_sharePreferences),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('내 저장 장소와 취향 반영', style: AppTypography.bodyStrong),
                        const SizedBox(height: 2),
                        // 공개 범위는 서버 정책과 일치해야 한다 (docs/06 §4)
                        Text('파티원에게는 취향 키워드와 고른 장소만 보여요', style: AppTypography.meta),
                      ],
                    ),
                  ),
                  Switch(value: _sharePreferences, onChanged: (v) => setState(() => _sharePreferences = v)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
