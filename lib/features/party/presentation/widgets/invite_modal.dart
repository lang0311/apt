import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/widgets/kakao_symbol.dart';
import '../../../../core/widgets/overlays.dart';
import '../../../../core/widgets/surfaces.dart';
import '../party_providers.dart';

/// #27 파티원 초대 — 하단 시트(카카오톡 · 링크 복사). 닫기 버튼 없이 바깥 탭/끌어내리기로 닫는다.
Future<void> showInviteModal(BuildContext context, {required String partyId}) {
  return showAppBottomSheet<void>(
    context,
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xxs, AppSpacing.screenH, AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('파티원 초대', style: AppTypography.cardTitle),
          const SizedBox(height: 2),
          Text('초대받은 사람의 취향도 추천에 반영돼요.', style: AppTypography.meta),
          const SizedBox(height: AppSpacing.md),
          _InviteBody(partyId: partyId),
        ],
      ),
    ),
  );
}

class _InviteBody extends ConsumerWidget {
  const _InviteBody({required this.partyId});
  final String partyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(inviteLinkProvider(partyId));

    // 링크를 아직 만드는 중이면 기다렸다가 복사한다(시트를 열자마자 눌러도 복사되게)
    Future<void> copy() async {
      try {
        final url = (await ref.read(inviteLinkProvider(partyId).future)).url;
        await Clipboard.setData(ClipboardData(text: url));
        if (context.mounted) showAppSnackBar(context, '초대 링크를 복사했어요.');
      } catch (e) {
        if (context.mounted) showAppSnackBar(context, failureMessage(e));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
          leading: const IconCircle(icon: Icons.link_rounded),
          title: '초대 링크 복사',
          description: link.isLoading ? '링크를 만들고 있어요' : '링크로 초대하기',
          onTap: copy,
        ),
      ],
    );
  }
}

/// 보내기 방법 한 줄(초대 · 코스 알리기 시트 공통)
class ShareOption extends StatelessWidget {
  const ShareOption({super.key, required this.background, required this.leading, required this.title, required this.description, required this.onTap});
  final Color background;
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
          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}
