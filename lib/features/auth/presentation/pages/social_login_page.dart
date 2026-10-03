import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/config/feature_flags.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/buttons.dart';
import '../../domain/auth_models.dart';
import '../auth_controller.dart';
import '../widgets/social_login_button.dart';

/// #1 소셜 로그인. 성공 시 신규=약관 / 기존=홈 이동은 라우터 redirect가 처리한다.
class SocialLoginPage extends ConsumerStatefulWidget {
  const SocialLoginPage({super.key});

  @override
  ConsumerState<SocialLoginPage> createState() => _SocialLoginPageState();
}

class _SocialLoginPageState extends ConsumerState<SocialLoginPage> {
  SocialProvider? _loading;

  Future<void> _signIn(SocialProvider provider) async {
    setState(() => _loading = provider);
    try {
      final result = await ref.read(authControllerProvider.notifier).signInWithSocial(provider);
      if (!mounted) return;
      switch (result) {
        case AccountConflict():
          context.push(AppRoutes.loginConflict, extra: result);
        case SignInCancelled():
          context.push(AppRoutes.loginError);
        case SignInFailed(:final message):
          context.push(AppRoutes.loginError, extra: message);
        default:
          break; // SignedIn / NeedsSignup → redirect
      }
    } catch (e) {
      if (mounted) context.push(AppRoutes.loginError, extra: failureMessage(e));
    } finally {
      if (mounted) setState(() => _loading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            padding: AppSpacing.screenPadding,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const SizedBox(height: 56),
                    const AppLogo(),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      '저장한 장소와 취향을 연결해\n나만의 여행 코스를 만들어보세요.',
                      style: AppTypography.body.copyWith(fontSize: 14, height: 1.6),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    for (final p in SocialProvider.values) ...[
                      SocialLoginButton(
                        provider: p,
                        loading: _loading == p,
                        onPressed: _loading == null ? () => _signIn(p) : null,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Text('처음 로그인하면 자동으로 회원가입됩니다.', style: AppTypography.meta),
                    // 이메일 로그인은 flag가 켜졌을 때만 노출 (가정 A1)
                    if (FeatureFlags.emailAuthEnabled) ...[
                      const SizedBox(height: AppSpacing.xs),
                      AppTextLink(label: '이메일로 로그인', onPressed: () => context.push(AppRoutes.loginEmail)),
                    ],
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.lg),
                      child: Text(
                        '계속하면 서비스 이용약관 및 개인정보 처리방침에\n동의하는 것으로 간주됩니다.',
                        style: AppTypography.caption.copyWith(color: AppColors.textHint, height: 1.6),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
