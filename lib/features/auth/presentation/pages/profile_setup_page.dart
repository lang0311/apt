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
import '../../../preference/presentation/preference_providers.dart';
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
            const AuthHeader(title: '프로필 설정', subtitle: '코스와 파티에서 다른 사람에게 보이는 이름이에요.'),
            Expanded(
              child: ListView(
                padding: AppSpacing.screenPadding,
                children: [
                  Center(
                    child: Container(
                      width: 84,
                      height: 84,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                      child: Text(initial, style: AppTypography.title.copyWith(color: AppColors.primary)),
                    ),
                  ),
                  // 프로필 사진 변경은 이미지 선택 패키지 + 업로드 API가 생기면 넣는다 (NEEDS BACKEND)
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    controller: _nickname,
                    label: '닉네임',
                    hint: '닉네임을 입력해주세요',
                    hasError: _error != null,
                    maxLength: 20,
                    onChanged: (_) => setState(() => _error = null),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (_error != null) AppFieldError(_error!) else Text('나중에 마이에서 바꿀 수 있어요.', style: AppTypography.meta),
                  const SizedBox(height: AppSpacing.xl),
                  const _PreferenceCard(),
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

/// 추천에 쓸 취향: 고른 키워드 한 줄 + 오른쪽 '고르기'
class _PreferenceCard extends ConsumerWidget {
  const _PreferenceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 불러오는 중이거나 실패해도 가입은 막지 않는다: 고르지 않은 것으로 보여 준다
    final labels = ref.watch(myPreferenceLabelsProvider).value ?? const <String>[];
    Future<void> pick() async {
      await context.push(AppRoutes.preferencesOnboarding);
      ref.invalidate(myPreferencesProvider);
    }

    return SectionCard(
      title: '추천에 쓸 취향',
      child: InkWell(
        onTap: pick,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SectionCard.innerPadding, vertical: AppSpacing.xs),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  labels.isEmpty ? '아직 고르지 않았어요' : labels.join(' · '),
                  style: AppTypography.meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(labels.isEmpty ? '고르기' : '바꾸기', style: AppTypography.label.copyWith(color: AppColors.primary)),
            ],
          ),
        ),
      ),
    );
  }
}
