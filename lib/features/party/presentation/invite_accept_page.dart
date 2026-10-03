import 'package:flutter/material.dart';
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
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/bottom_cta.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/overlays.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/surfaces.dart';
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text('코스 초대', style: AppTypography.header),
            ),
            Expanded(
              child: invitation.when(
                loading: () => const AppLoading(),
                // 초대 예외(만료·이미 참여·인원 초과)는 디자인 없음 → 공통 빈 상태로 임시 구현
                error: (e, _) => e is InviteFailure
                    ? Center(
                        child: AppEmptyState(
                          icon: Icons.mail_outline_rounded,
                          title: e.kind.title,
                          description: e.kind.description,
                          actionLabel: e.kind == InviteFailureKind.alreadyJoined ? '코스 목록 보기' : '홈으로',
                          onAction: () => context.go(e.kind == InviteFailureKind.alreadyJoined ? AppRoutes.courses : AppRoutes.home),
                        ),
                      )
                    : AppErrorState(error: e, onRetry: () => ref.invalidate(invitationProvider(widget.token))),
                data: (inv) => _content(inv),
              ),
            ),
            if (invitation.hasValue)
              BottomCta(
                child: Column(
                  children: [
                    AppButton(label: '코스에 참여하기', loading: _submitting, onPressed: _accept),
                    const SizedBox(height: AppSpacing.xs),
                    AppTextLink(label: '이번에는 참여하지 않기', color: AppColors.textSecondary, onPressed: _submitting ? null : _decline),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _content(Invitation inv) {
    return ListView(
      padding: AppSpacing.screenPadding,
      children: [
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                child: Text('${inv.memberCount}', style: AppTypography.title.copyWith(color: AppColors.primary)),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('${inv.inviterName}님이 코스에 초대했어요', style: AppTypography.section, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text('함께 취향을 모아 AI 코스를 만들어요.', style: AppTypography.body, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.lg),
              Text(inv.courseTitle, style: AppTypography.cardTitle),
              const SizedBox(height: 2),
              Text(
                [if (inv.courseDate != null) formatDate(inv.courseDate!), '현재 ${inv.memberCount}명'].join(' · '),
                style: AppTypography.meta.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('미리 보기', style: AppTypography.section),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              Row(
                children: [
                  AppNetworkImage(url: inv.previewImageUrl, width: 84, height: 84, radius: 16),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('선택된 장소 ${inv.selectedPlaceCount}곳', style: AppTypography.bodyStrong),
                        const SizedBox(height: 4),
                        Text(inv.previewPlaceNames.join(' · '), style: AppTypography.meta),
                      ],
                    ),
                  ),
                ],
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: AppSpacing.sm), child: Divider()),
              InkWell(
                onTap: () => setState(() => _sharePreferences = !_sharePreferences),
                child: Semantics(
                  checked: _sharePreferences,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Row(
                      children: [
                        Expanded(child: Text('내 저장 장소와 취향을 추천에 반영', style: AppTypography.label)),
                        Icon(
                          _sharePreferences ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          color: _sharePreferences ? AppColors.primary : AppColors.textHint,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // 공개 범위는 서버 정책과 일치해야 한다 (docs/06 §4)
        const InfoCard(
          title: '참여하면 공개되는 정보',
          titleColor: AppColors.primary,
          description: '취향 키워드와 코스에 선택한 장소만 공유돼요.',
        ),
      ],
    );
  }
}
