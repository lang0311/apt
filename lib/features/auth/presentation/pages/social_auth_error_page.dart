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
            AuthHeader(
              title: '로그인할 수 없어요',
              subtitle: message ?? '일시적인 오류가 발생했어요. 잠시 후 다시 시도해주세요.',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                children: [
                  SectionCard(
                    title: '이렇게 해 보세요',
                    child: DividedRows(
                      indent: SectionCard.innerPadding,
                      children: [
                        for (final tip in const ['인터넷 연결 상태를 확인해 주세요', '소셜 계정 접근 권한을 허용해 주세요'])
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: SectionCard.innerPadding, vertical: AppSpacing.sm),
                            child: Text(tip, style: AppTypography.body),
                          ),
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
