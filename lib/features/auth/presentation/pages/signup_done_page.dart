import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/bottom_cta.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/surfaces.dart';
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
              child: ListView(
                padding: AppSpacing.screenPadding,
                children: const [
                  SizedBox(height: 80),
                  AppLogo(),
                  SizedBox(height: 56),
                  StatusCard(
                    icon: Icons.check_rounded,
                    iconBackground: AppColors.successSoft,
                    title: '가입이 완료됐어요',
                    description: '저장한 장소부터 취향을 만들어볼까요?',
                  ),
                ],
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
