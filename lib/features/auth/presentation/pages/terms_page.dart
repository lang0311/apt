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
import '../../../../core/widgets/overlays.dart';
import '../../../../core/widgets/selection.dart';
import '../../../../core/widgets/states.dart';
import '../../../../core/widgets/surfaces.dart';
import '../../domain/auth_models.dart';
import '../auth_controller.dart';

/// #2 약관 동의. 필수 항목을 모두 동의해야 버튼이 활성화된다.
class TermsPage extends ConsumerStatefulWidget {
  const TermsPage({super.key});

  @override
  ConsumerState<TermsPage> createState() => _TermsPageState();
}

class _TermsPageState extends ConsumerState<TermsPage> {
  final _agreed = <String>{};
  bool _submitting = false;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await ref.read(authControllerProvider.notifier).agreeTerms(_agreed);
      if (mounted) context.push(AppRoutes.signupProfile);
    } catch (e) {
      if (mounted) showAppSnackBar(context, failureMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final terms = ref.watch(termsProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AuthHeader(
              title: '약관 동의',
              subtitle: '서비스 이용을 위해 아래 내용을 확인해주세요.',
              onBack: () => ref.read(authControllerProvider.notifier).cancelSignup(),
            ),
            Expanded(
              child: AsyncValueView<List<TermsItem>>(
                value: terms,
                onRetry: () => ref.invalidate(termsProvider),
                data: (items) => _TermsList(
                  items: items,
                  agreed: _agreed,
                  onChanged: (next) => setState(() => _agreed
                    ..clear()
                    ..addAll(next)),
                ),
              ),
            ),
            BottomCta(
              child: AppButton(
                label: '동의하고 계속하기',
                loading: _submitting,
                onPressed: terms.hasValue && terms.value!.where((t) => t.required).every((t) => _agreed.contains(t.id))
                    ? _submit
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TermsList extends StatelessWidget {
  const _TermsList({required this.items, required this.agreed, required this.onChanged});
  final List<TermsItem> items;
  final Set<String> agreed;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final all = items.every((t) => agreed.contains(t.id));
    return ListView(
      padding: AppSpacing.screenPadding,
      children: [
        AppCard(
          color: AppColors.primarySoft,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
          onTap: () => onChanged(all ? {} : items.map((t) => t.id).toSet()),
          child: Row(
            children: [
              CircleCheck(checked: all),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('전체 동의', style: AppTypography.cardTitle),
                    const SizedBox(height: 2),
                    Text('선택 항목을 포함해 모두 동의합니다.', style: AppTypography.meta),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            children: [
              for (final t in items)
                InkWell(
                  onTap: () => onChanged(agreed.contains(t.id) ? ({...agreed}..remove(t.id)) : {...agreed, t.id}),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    child: Row(
                      children: [
                        CircleCheck(checked: agreed.contains(t.id)),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text('${t.title} (${t.required ? '필수' : '선택'})', style: AppTypography.bodyStrong),
                        ),
                        if (t.contentUrl != null)
                          IconButton(
                            tooltip: '약관 보기',
                            icon: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                            // NEEDS BACKEND: 약관 본문 URL 정책 확정 후 웹뷰/외부 브라우저로 연다.
                            onPressed: () => showAppSnackBar(context, '약관 본문은 준비 중이에요.'),
                          )
                        else
                          const SizedBox(width: 48),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
