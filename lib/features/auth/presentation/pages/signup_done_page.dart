import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/bottom_cta.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/station_steps.dart';
import '../auth_controller.dart';

/// #4 가입 완료 (리디자인 v2): 왼쪽 정렬 제목 + 첫 저장 방법을 정거장 세 개로.
/// 시작하기 → 홈 (보류된 공유 URL이 있으면 이어서 추출)
class SignupDonePage extends ConsumerWidget {
  const SignupDonePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 64, AppSpacing.screenH, AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 30),
                    ),
                    const SizedBox(height: 22),
                    Text('가입이 끝났어요', style: AppTypography.display),
                    const SizedBox(height: 6),
                    Text('이제 릴스에서 마음에 드는 곳을 보면 이렇게 저장해요.', style: AppTypography.bodyMuted),
                    const SizedBox(height: 30),
                    const StationSteps(steps: [('릴스에서 ⋯ 누르기', '게시물 오른쪽 아래 메뉴'), ('공유 → APT 고르기', '앱 목록에 없으면 ‘더 보기’'), ('찾은 장소 확인하고 저장', '게시물 속 장소를 AI가 찾아요')]),
                  ],
                ),
              ),
            ),
            BottomCta(
              child: AppButton(label: '시작하기', onPressed: () => ref.read(authControllerProvider.notifier).finishOnboarding()),
            ),
          ],
        ),
      ),
    );
  }
}
