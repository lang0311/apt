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
import '../auth_controller.dart';

/// #3 프로필 설정. 닉네임 규칙/중복은 서버 기준 (검증 오류는 인라인 표시).
class ProfileSetupPage extends ConsumerStatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  ConsumerState<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends ConsumerState<ProfileSetupPage> {
  late final _nickname = TextEditingController(text: ref.read(authControllerProvider).suggestedNickname ?? '');
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      // 성공 시 라우터 redirect가 가입 완료(#4)로 보낸다.
      await ref.read(authControllerProvider.notifier).completeProfile(_nickname.text);
    } on ValidationFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) showAppSnackBar(context, failureMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _nickname.text.trim();
    final initial = name.isEmpty ? '?' : name.substring(name.length >= 2 ? name.length - 2 : 0);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AuthHeader(title: '어떻게 불러\n드릴까요?'),
            Expanded(
              child: ListView(
                padding: AppSpacing.screenPadding,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      child: Text(initial, style: AppTypography.title.copyWith(color: Colors.white)),
                    ),
                  ),
                  // 프로필 사진 변경은 이미지 선택 패키지 + 업로드 API가 생기면 넣는다 (NEEDS BACKEND)
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    controller: _nickname,
                    label: '닉네임',
                    hint: '닉네임을 입력해 주세요',
                    hasError: _error != null,
                    maxLength: 20,
                    showCounter: true,
                    onChanged: (_) => setState(() => _error = null),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (_error != null) AppFieldError(_error!) else Text('나중에 마이에서 바꿀 수 있어요.', style: AppTypography.meta),
                ],
              ),
            ),
            BottomCta(
              child: AppButton(label: '가입 완료', loading: _submitting, onPressed: name.isEmpty ? null : _submit),
            ),
          ],
        ),
      ),
    );
  }
}
