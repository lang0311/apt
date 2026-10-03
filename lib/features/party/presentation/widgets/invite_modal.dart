import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/overlays.dart';
import '../../../../core/widgets/surfaces.dart';
import '../party_providers.dart';

/// #27 파티원 초대 모달
Future<void> showInviteModal(BuildContext context, {required String partyId}) {
  return showAppModal<void>(
    context,
    title: '파티원 초대하기',
    subtitle: '친구의 취향도 AI 추천에 함께 반영돼요.',
    builder: (_) => _InviteBody(partyId: partyId),
  );
}

class _InviteBody extends ConsumerWidget {
  const _InviteBody({required this.partyId});
  final String partyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(inviteLinkProvider(partyId));

    Future<void> copy() async {
      final url = link.value?.url;
      if (url == null) {
        showAppSnackBar(context, link.hasError ? failureMessage(link.error!) : '초대 링크를 만들고 있어요.');
        return;
      }
      await Clipboard.setData(ClipboardData(text: url));
      if (context.mounted) showAppSnackBar(context, '초대 링크를 복사했어요.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Option(
          background: AppColors.kakaoSoft,
          leading: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.kakao, shape: BoxShape.circle),
            child: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF191919), size: 20),
          ),
          title: '카카오톡으로 초대장 보내기',
          description: '친구에게 바로 공유할 수 있어요.',
          // NEEDS: 카카오 SDK(카카오톡 공유) 키 발급
          onTap: () => showAppSnackBar(context, '카카오톡 공유는 준비 중이에요. 링크 복사를 이용해주세요.'),
        ),
        const SizedBox(height: AppSpacing.sm),
        _Option(
          background: AppColors.bg,
          leading: const IconCircle(icon: Icons.link_rounded),
          title: '초대 링크 복사',
          description: link.isLoading ? '링크를 만들고 있어요…' : '링크를 원하는 곳에 붙여넣으세요.',
          onTap: copy,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('파티원이 참여하면 각자의 저장 장소와 취향이\n추천 코스에 반영됩니다.', style: AppTypography.meta),
        const SizedBox(height: AppSpacing.lg),
        AppButton(label: '닫기', onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.background, required this.leading, required this.title, required this.description, required this.onTap});
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
