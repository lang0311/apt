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
import '../../../../core/widgets/inputs.dart';
import '../../../../core/widgets/overlays.dart';
import '../../domain/auth_models.dart';
import '../auth_controller.dart';
import '../widgets/social_login_button.dart';

/// #1 로그인: 아이디·비밀번호 + 간편 로그인 아이콘 줄 (07 D28).
/// 성공 시 신규=약관 / 기존=홈 이동은 라우터 redirect가 처리한다.
class SocialLoginPage extends ConsumerStatefulWidget {
  const SocialLoginPage({super.key});

  @override
  ConsumerState<SocialLoginPage> createState() => _SocialLoginPageState();
}

class _SocialLoginPageState extends ConsumerState<SocialLoginPage> {
  final _login = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  SocialProvider? _signingInWith;

  /// 어느 칸이 틀렸는지 구분하지 않는다 — 비밀번호 칸 아래 한 줄
  String? _credentialError;

  bool get _busy => _submitting || _signingInWith != null;

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  void _edited(String _) => setState(() => _credentialError = null);

  Future<void> _submit() async {
    if (_busy || _login.text.trim().isEmpty || _password.text.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      final result = await ref.read(authControllerProvider.notifier).signInWithId(_login.text.trim(), _password.text);
      if (result is InvalidCredentials && mounted) {
        setState(() => _credentialError = '아이디 또는 비밀번호를 확인해주세요.');
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, failureMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _signIn(SocialProvider provider) async {
    setState(() => _signingInWith = provider);
    try {
      final result = await ref.read(authControllerProvider.notifier).signInWithSocial(provider);
      if (!mounted) return;
      switch (result) {
        case AccountConflict():
          context.push(AppRoutes.loginConflict, extra: result);
        case SignInCancelled():
          // 직접 취소한 것은 오류가 아니다: 로그인 화면에 남고 짧게 알린다
          showAppSnackBar(
            context,
            '${provider.label} 로그인을 취소했어요',
            duration: const Duration(milliseconds: 1500),
          );
        case SignInFailed(:final message):
          context.push(AppRoutes.loginError, extra: message);
        default:
          break; // SignedIn / NeedsSignup → redirect
      }
    } catch (e) {
      if (mounted) context.push(AppRoutes.loginError, extra: failureMessage(e));
    } finally {
      if (mounted) setState(() => _signingInWith = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = !_busy && _login.text.trim().isNotEmpty && _password.text.isNotEmpty;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: AppSpacing.screenPadding,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 48),
                    const AppLogo(),
                    const SizedBox(height: 40),
                    AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppTextField(
                            controller: _login,
                            hint: '아이디',
                            enabled: !_busy,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.username],
                            onChanged: _edited,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AppTextField(
                            controller: _password,
                            hint: '비밀번호',
                            enabled: !_busy,
                            obscureText: _obscure,
                            hasError: _credentialError != null,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onChanged: _edited,
                            onSubmitted: (_) => _submit(),
                            suffix: IconButton(
                              tooltip: _obscure ? '비밀번호 보기' : '비밀번호 숨기기',
                              icon: Icon(
                                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: AppColors.textSecondary,
                              ),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          if (_credentialError != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            AppFieldError(_credentialError!),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(label: '로그인', loading: _submitting, onPressed: canSubmit ? _submit : null),
                    const SizedBox(height: AppSpacing.xs),
                    Center(
                      child: AppTextLink(
                        label: '회원가입',
                        color: AppColors.textPrimary,
                        onPressed: _busy ? null : () => ref.read(authControllerProvider.notifier).startIdSignup(),
                      ),
                    ),
                    // 이메일 로그인은 flag가 켜졌을 때만 노출 (가정 A1)
                    if (FeatureFlags.emailAuthEnabled)
                      Center(
                        child: AppTextLink(label: '이메일로 로그인', onPressed: () => context.push(AppRoutes.loginEmail)),
                      ),
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      children: [
                        const Expanded(child: Divider(color: AppColors.divider, height: 1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                          child: Text('간편 로그인', style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
                        ),
                        const Expanded(child: Divider(color: AppColors.divider, height: 1)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final p in SocialProvider.values)
                          if (p != SocialProvider.apple || FeatureFlags.appleAuthEnabled)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                              child: SocialIconButton(
                                provider: p,
                                loading: _signingInWith == p,
                                onPressed: _busy ? null : () => _signIn(p),
                              ),
                            ),
                      ],
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.lg),
                      child: Text(
                        '계속하면 서비스 이용약관 및 개인정보 처리방침에\n동의하는 것으로 간주됩니다.',
                        style: AppTypography.caption.copyWith(color: AppColors.textSecondary, height: 1.6),
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
