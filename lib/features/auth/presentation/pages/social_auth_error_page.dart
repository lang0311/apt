import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/bottom_cta.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/overlays.dart';

/// #6 소셜 인증 오류 (실패만. 사용자가 취소하면 로그인 화면에 남는다)
class SocialAuthErrorPage extends StatelessWidget {
  const SocialAuthErrorPage({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // v2: 빨간 ! → 큰 제목 → 회색 설명, 아래 '이렇게 해 보세요' + 아이콘 달린 안내 줄
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.lg),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: '뒤로',
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                      onPressed: () => context.go(AppRoutes.login),
                      icon: const Icon(LucideIcons.chevronLeft, size: 20, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(LucideIcons.circleAlert, size: 30, color: AppColors.danger),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Semantics(header: true, child: Text('로그인할 수 없어요', style: AppTypography.display)),
                  const SizedBox(height: 6),
                  Text(message ?? '일시적인 오류가 발생했어요. 잠시 후 다시 시도해주세요.', style: AppTypography.bodyMuted),
                  const SizedBox(height: AppSpacing.xl),
                  Text('이렇게 해 보세요', style: AppTypography.lead),
                  const SizedBox(height: AppSpacing.xs),
                  for (final (icon, tip) in const [(LucideIcons.wifi, '인터넷 연결 상태를 확인해 주세요'), (LucideIcons.user, '소셜 계정 접근 권한을 허용해 주세요')])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: Row(
                        children: [
                          Icon(icon, size: 22, color: AppColors.textSecondary),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: Text(tip, style: AppTypography.body)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            BottomCta(
              child: Column(
                children: [
                  AppButton(label: '다시 로그인하기', onPressed: () => context.go(AppRoutes.login)),
                  const SizedBox(height: AppSpacing.xs),
                  AppTextLink(
                    label: '고객센터에 문의하기',
                    color: AppColors.textSecondary,
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
