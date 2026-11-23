import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/widgets/brand_marks.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/overlays.dart';
import '../../../../core/widgets/surfaces.dart';
import '../party_providers.dart';

/// #27 파티원 초대 — 하단 시트(카카오톡 · 링크 복사). 닫기 버튼 없이 바깥 탭/끌어내리기로 닫는다.
/// 서버 초대 링크는 한 사람이 참여하면 지워지고 `expires_in` 뒤에 끝나서, 설명 아래에 안내 한 줄을 두고
/// 복사한 뒤에는 `새 링크`로 다음 사람용 링크를 바로 만든다 (17번, 시안 https://claude.ai/artifact/24Ro62D3yiXffdgMG1bnQE).
Future<void> showInviteModal(BuildContext context, {required String partyId}) {
  return showAppBottomSheet<void>(
    context,
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xxs, AppSpacing.screenH, AppSpacing.md),
      child: _InviteBody(partyId: partyId),
    ),
  );
}

class _InviteBody extends ConsumerStatefulWidget {
  const _InviteBody({required this.partyId});
  final String partyId;

  @override
  ConsumerState<_InviteBody> createState() => _InviteBodyState();
}

class _InviteBodyState extends ConsumerState<_InviteBody> {
  /// 지금 링크를 복사했는지. 새 링크를 만들면 다시 false
  bool _copied = false;

  // 링크를 아직 만드는 중이면 기다렸다가 복사한다(시트를 열자마자 눌러도 복사되게)
  Future<void> _copy() async {
    try {
      final url = (await ref.read(inviteLinkProvider(widget.partyId).future)).url;
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      setState(() => _copied = true);
      showAppSnackBar(context, '초대 링크를 복사했어요.');
    } catch (e) {
      if (mounted) showAppSnackBar(context, failureMessage(e));
    }
  }

  void _renew() {
    ref.invalidate(inviteLinkProvider(widget.partyId));
    setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final link = ref.watch(inviteLinkProvider(widget.partyId));
    final hours = link.value?.expiresIn?.inHours;
    final note = hours == null || hours <= 0
        ? '링크 하나에 한 명씩 들어올 수 있어요.'
        : '링크 하나에 한 명씩 들어올 수 있어요.\n$hours시간이 지나면 열리지 않아요.';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('파티원 초대', style: AppTypography.cardTitle),
        const SizedBox(height: 2),
        Text('초대받은 사람의 취향도 추천에 반영돼요.', style: AppTypography.meta),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 11),
          decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(AppRadius.medium)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(LucideIcons.clock, size: 16, color: AppColors.textSecondary),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: Text(note, style: AppTypography.meta.copyWith(color: AppColors.textSecondary))),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ShareOption(
          background: AppColors.kakaoSoft,
          leading: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.kakao, shape: BoxShape.circle),
            child: const KakaoSymbol(size: 20),
          ),
          title: '카카오톡으로 보내기',
          description: '친구에게 초대 메시지 보내기',
          // NEEDS: 카카오 SDK(카카오톡 공유) 키 발급
          onTap: () => showAppSnackBar(context, '카카오톡 공유는 준비 중이에요. 링크 복사를 이용해주세요.'),
        ),
        const SizedBox(height: AppSpacing.sm),
        ShareOption(
          background: AppColors.bg,
          leading: const IconCircle(icon: LucideIcons.link),
          title: '초대 링크 복사',
          description: link.isLoading ? '링크를 만들고 있어요' : (_copied ? '복사했어요' : '링크로 초대하기'),
          onTap: _copy,
          trailing: _copied
              ? AppButton(label: '새 링크', variant: AppButtonVariant.white, expand: false, height: 36, onPressed: _renew)
              : null,
        ),
      ],
    );
  }
}

/// 보내기 방법 한 줄(초대 · 코스 알리기 시트 공통)
class ShareOption extends StatelessWidget {
  const ShareOption({super.key, required this.background, required this.leading, required this.title, required this.description, required this.onTap, this.trailing});
  final Color background;

  /// 오른쪽 끝 (없으면 › 화살표)
  final Widget? trailing;
  final Widget leading;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: background,
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          leading,
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.bodyStrong),
                const SizedBox(height: 2),
                Text(description, style: AppTypography.caption),
              ],
            ),
          ),
          trailing ?? const Icon(LucideIcons.chevronRight, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}
