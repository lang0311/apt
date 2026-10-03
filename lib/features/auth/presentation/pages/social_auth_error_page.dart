import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/bottom_cta.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/headers.dart';
import '../../../../core/widgets/overlays.dart';
import '../../../../core/widgets/surfaces.dart';

/// #6 소셜 인증 오류 (취소/실패)
class SocialAuthErrorPage extends StatelessWidget {
  const SocialAuthErrorPage({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AuthHeader(title: '로그인할 수 없어요'),
            Expanded(
              child: ListView(
                padding: AppSpacing.screenPadding,
                children: [
                  const SizedBox(height: AppSpacing.xl),
                  StatusCard(
                    icon: Icons.priority_high_rounded,
                    title: '소셜 인증이 완료되지 않았어요',
                    description: message ?? '로그인을 취소했거나 일시적인 오류가 발생했어요.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('해결 방법', style: AppTypography.bodyStrong),
                        const SizedBox(height: AppSpacing.xs),
                        Text('· 인터넷 연결 상태를 확인해주세요.', style: AppTypography.body),
                        const SizedBox(height: 4),
                        Text('· 소셜 계정 접근 권한을 허용해주세요.', style: AppTypography.body),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            BottomCta(
              child: Column(
                children: [
                  AppButton.dark(label: '다시 로그인하기', onPressed: () => context.go(AppRoutes.login)),
                  const SizedBox(height: AppSpacing.xs),
                  AppTextLink(
                    label: '고객센터 문의',
                    // NEEDS: 고객센터 채널(이메일/카카오 채널) 확정
                    onPressed: () => showAppSnackBar(context, '고객센터 연결은 준비 중이에요.'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
