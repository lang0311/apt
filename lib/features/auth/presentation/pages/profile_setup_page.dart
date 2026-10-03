import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/widgets/bottom_cta.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/headers.dart';
import '../../../../core/widgets/inputs.dart';
import '../../../../core/widgets/overlays.dart';
import '../../../../core/widgets/surfaces.dart';
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
      setState(() => _error = e.message);
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
            const AuthHeader(title: '프로필 설정', subtitle: '앱에서 사용할 정보를 확인해주세요.'),
            Expanded(
              child: ListView(
                padding: AppSpacing.screenPadding,
                children: [
                  Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                      child: Text(initial, style: AppTypography.title.copyWith(color: AppColors.primary)),
                    ),
                  ),
                  Center(
                    child: AppTextLink(
                      label: '프로필 사진 변경',
                      // NEEDS: 이미지 선택 패키지(image_picker) 도입 + 업로드 API (NEEDS BACKEND)
                      onPressed: () => showAppSnackBar(context, '프로필 사진 변경은 준비 중이에요.'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    controller: _nickname,
                    label: '닉네임',
                    hint: '닉네임을 입력해주세요',
                    hasError: _error != null,
                    maxLength: 20,
                    onChanged: (_) => setState(() => _error = null),
                  ),
                  if (_error != null) ...[const SizedBox(height: AppSpacing.xs), AppFieldError(_error!)],
                  const SizedBox(height: AppSpacing.xl),
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    onTap: () => context.push(AppRoutes.preferencesOnboarding),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('추천에 사용할 기본 취향', style: AppTypography.bodyStrong),
                              const SizedBox(height: 6),
                              Text('나중에 마이페이지에서 변경할 수 있어요.', style: AppTypography.meta),
                            ],
                          ),
                        ),
                        Text('설정하기 ›', style: AppTypography.label.copyWith(color: AppColors.primary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            BottomCta(
              child: AppButton(
                label: '가입 완료하기',
                loading: _submitting,
                onPressed: name.isEmpty ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
