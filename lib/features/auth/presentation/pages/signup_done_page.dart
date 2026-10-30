import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/bottom_cta.dart';
import '../../../../core/widgets/buttons.dart';
import '../auth_controller.dart';

/// #4 가입 완료. 시작하기 → 홈 (보류된 공유 URL이 있으면 이어서 추출)
class SignupDonePage extends ConsumerWidget {
  const SignupDonePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: AppSpacing.screenPadding,
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 48, color: AppColors.primary),
                      const SizedBox(height: AppSpacing.md),
                      Text('가입이 완료됐어요', style: AppTypography.title, textAlign: TextAlign.center),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '릴스에서 공유를 누르고 APT를 고르면\n게시물 속 장소를 찾아 저장할 수 있어요.',
                        style: AppTypography.body,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            BottomCta(
              child: AppButton(
                label: '시작하기',
                onPressed: () => ref.read(authControllerProvider.notifier).finishOnboarding(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
