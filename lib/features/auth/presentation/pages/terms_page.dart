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
      // 아이디 가입은 약관 다음 계정 정보, 소셜 가입은 프로필
      if (mounted) context.push(ref.read(authControllerProvider).idSignup ? AppRoutes.signupAccount : AppRoutes.signupProfile);
    } catch (e) {
      if (mounted) showAppSnackBar(context, failureMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final terms = ref.watch(termsProvider);
    final requiredAgreed = terms.hasValue && terms.value!.where((t) => t.required).every((t) => _agreed.contains(t.id));
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AuthHeader(
              title: '약관 동의',
              subtitle: '서비스를 쓰려면 필수 약관에 동의해 주세요.',
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
                onPressed: requiredAgreed ? _submit : null,
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
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, AppSpacing.lg),
      children: [
        // 전체 동의도 같은 카드의 맨 위 행으로 둔다
        AppCard(
          padding: EdgeInsets.zero,
          child: DividedRows(
            indent: 0,
            children: [
              _TermsRow(
                checked: all,
                title: Text('전체 동의', style: AppTypography.cardTitle),
                subtitle: '선택 항목까지 모두 동의해요',
                onTap: () => onChanged(all ? {} : items.map((t) => t.id).toSet()),
              ),
              for (final t in items)
                _TermsRow(
                  checked: agreed.contains(t.id),
                  title: Text.rich(
                    TextSpan(
                      text: t.title,
                      children: [
                        TextSpan(
                          text: '  ${t.required ? '필수' : '선택'}',
                          style: AppTypography.meta.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    style: AppTypography.bodyStrong,
                  ),
                  onTap: () => onChanged(agreed.contains(t.id) ? ({...agreed}..remove(t.id)) : {...agreed, t.id}),
                  // 본문이 있는 약관만 › (행을 누르면 체크, ›를 누르면 본문)
                  onOpen: t.contentUrl == null
                      ? null
                      // NEEDS BACKEND: 약관 본문 URL 정책 확정 후 웹뷰/외부 브라우저로 연다.
                      : () => showAppSnackBar(context, '약관 본문은 준비 중이에요.'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TermsRow extends StatelessWidget {
  const _TermsRow({required this.checked, required this.title, required this.onTap, this.subtitle, this.onOpen});
  final bool checked;
  final Widget title;
  final String? subtitle;
  final VoidCallback onTap;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        // › 버튼(48) 유무와 관계없이 모든 행 높이를 같게 맞춘다
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.xxs, AppSpacing.xs),
        child: Row(
          children: [
            CheckMark(checked: checked),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: AppTypography.meta),
                  ],
                ],
              ),
            ),
            if (onOpen != null)
              IconButton(
                tooltip: '약관 보기',
                icon: const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
                onPressed: onOpen,
              )
            else
              const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}
