import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/widgets/bottom_cta.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/headers.dart';
import '../../../../core/widgets/inputs.dart';
import '../../../../core/widgets/overlays.dart';
import '../../domain/auth_models.dart';
import '../auth_controller.dart';

/// #7 이메일 로그인 (틀) + #8 오류 상태.
/// FeatureFlags.emailAuthEnabled=false면 라우터가 진입을 막는다.
class EmailLoginPage extends ConsumerStatefulWidget {
  const EmailLoginPage({super.key});

  @override
  ConsumerState<EmailLoginPage> createState() => _EmailLoginPageState();
}

class _EmailLoginPageState extends ConsumerState<EmailLoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;

  /// #8: 두 필드 모두 빨강 + 한 줄 메시지 (어느 쪽이 틀렸는지 구분하지 않음)
  String? _credentialError;
  String? _emailFormatError;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _clearErrors() {
    if (_credentialError != null || _emailFormatError != null) {
      setState(() {
        _credentialError = null;
        _emailFormatError = null;
      });
    } else {
      setState(() {});
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_emailPattern.hasMatch(_email.text.trim())) {
      setState(() => _emailFormatError = '이메일 형식을 확인해주세요.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final result = await ref.read(authControllerProvider.notifier).signInWithEmail(_email.text.trim(), _password.text);
      if (result is InvalidCredentials) setState(() => _credentialError = '이메일 또는 비밀번호가 올바르지 않아요.');
    } catch (e) {
      if (mounted) showAppSnackBar(context, failureMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // TODO(email-auth): 비밀번호 찾기 / 이메일 가입 화면 (디자인 없음, 가정 A2)
  void _todo() => showAppSnackBar(context, '준비 중인 기능이에요.');

  @override
  Widget build(BuildContext context) {
    final error = _credentialError ?? _emailFormatError;
    final canSubmit = _email.text.trim().isNotEmpty && _password.text.isNotEmpty;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AuthHeader(title: '이메일로 로그인', subtitle: '가입한 이메일 주소와 비밀번호를 입력해주세요.'),
            Expanded(
              child: ListView(
                padding: AppSpacing.screenPadding,
                children: [
                  AppTextField(
                    controller: _email,
                    label: '이메일',
                    hint: 'example@email.com',
                    prefixIcon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    hasError: error != null,
                    onChanged: (_) => _clearErrors(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    controller: _password,
                    label: '비밀번호',
                    hint: '비밀번호 입력',
                    prefixIcon: Icons.lock_outline_rounded,
                    obscureText: _obscure,
                    hasError: _credentialError != null,
                    onChanged: (_) => _clearErrors(),
                    onSubmitted: (_) => canSubmit ? _submit() : null,
                    suffix: IconButton(
                      tooltip: _obscure ? '비밀번호 보기' : '비밀번호 숨기기',
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.textSecondary),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Expanded(child: error == null ? const SizedBox.shrink() : AppFieldError(error)),
                      AppTextLink(label: '비밀번호 찾기', onPressed: _todo, style: AppTypography.meta.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
            BottomCta(
              child: Column(
                children: [
                  AppButton(label: '로그인', loading: _submitting, onPressed: canSubmit ? _submit : null),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('아직 계정이 없나요?', style: AppTypography.meta),
                      AppTextLink(label: '이메일로 가입하기', onPressed: _todo),
                    ],
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
