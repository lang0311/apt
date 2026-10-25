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
import '../../data/auth_repositories.dart' show IdSignupRules;
import '../auth_controller.dart';

/// 아이디 가입: 약관(#2) 다음 계정 정보. 가입하면 바로 로그인되고 가입 완료(#4)로 간다 (라우터 redirect).
/// 비밀번호는 한 번만 입력하고 보기 버튼으로 확인한다.
class IdSignupPage extends ConsumerStatefulWidget {
  const IdSignupPage({super.key});

  @override
  ConsumerState<IdSignupPage> createState() => _IdSignupPageState();
}

class _IdSignupPageState extends ConsumerState<IdSignupPage> {
  final _login = TextEditingController();
  final _password = TextEditingController();
  final _nickname = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;

  /// 칸별 오류 (`login` · `password` · `nickname`)
  Map<String, String> _errors = const {};

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    _nickname.dispose();
    super.dispose();
  }

  void _edited(String field) {
    if (_errors.containsKey(field)) setState(() => _errors = {..._errors}..remove(field));
    setState(() {});
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final errors = IdSignupRules.validate(login: _login.text, password: _password.text, nickname: _nickname.text);
    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(authControllerProvider.notifier).signUpWithId(
            login: _login.text,
            password: _password.text,
            nickname: _nickname.text,
          );
    } on ValidationFailure catch (e) {
      if (!mounted) return;
      if (e.fieldErrors.isNotEmpty) {
        setState(() => _errors = e.fieldErrors);
      } else {
        showAppSnackBar(context, e.message);
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, failureMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _field({
    required String key,
    required String label,
    required TextEditingController controller,
    String? help,
    bool password = false,
    Iterable<String>? autofill,
    TextInputAction action = TextInputAction.next,
  }) {
    final error = _errors[key];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          controller: controller,
          label: label,
          enabled: !_submitting,
          hasError: error != null,
          obscureText: password && _obscure,
          textInputAction: action,
          autofillHints: autofill,
          onChanged: (_) => _edited(key),
          onSubmitted: action == TextInputAction.done ? (_) => _submit() : null,
          suffix: password
              ? IconButton(
                  tooltip: _obscure ? '비밀번호 보기' : '비밀번호 숨기기',
                  icon: Icon(
                    _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                )
              : null,
        ),
        const SizedBox(height: AppSpacing.xs),
        if (error != null) AppFieldError(error) else if (help != null) Text(help, style: AppTypography.meta),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filled = _login.text.trim().isNotEmpty && _password.text.isNotEmpty && _nickname.text.trim().isNotEmpty;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AuthHeader(title: '회원가입', subtitle: '로그인에 쓸 아이디와 비밀번호를 정해주세요.'),
            Expanded(
              child: AutofillGroup(
                child: ListView(
                  padding: AppSpacing.screenPadding,
                  children: [
                    _field(
                      key: 'login',
                      label: '아이디',
                      controller: _login,
                      help: IdSignupRules.loginHelp,
                      autofill: const [AutofillHints.newUsername],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _field(
                      key: 'password',
                      label: '비밀번호',
                      controller: _password,
                      help: IdSignupRules.passwordHelp,
                      password: true,
                      autofill: const [AutofillHints.newPassword],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _field(
                      key: 'nickname',
                      label: '닉네임',
                      controller: _nickname,
                      help: '코스와 파티에서 다른 사람에게 보이는 이름이에요.',
                      autofill: const [AutofillHints.nickname],
                      action: TextInputAction.done,
                    ),
                  ],
                ),
              ),
            ),
            BottomCta(
              child: AppButton(label: '가입하기', loading: _submitting, onPressed: filled && !_submitting ? _submit : null),
            ),
          ],
        ),
      ),
    );
  }
}
