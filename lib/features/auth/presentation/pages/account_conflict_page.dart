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
import '../../../../core/widgets/surfaces.dart';
import '../../domain/auth_models.dart';
import '../auth_controller.dart';

/// #5 기존 계정 충돌
class AccountConflictPage extends ConsumerStatefulWidget {
  const AccountConflictPage({super.key, required this.conflict});
  final AccountConflict? conflict;

  @override
  ConsumerState<AccountConflictPage> createState() => _AccountConflictPageState();
}

class _AccountConflictPageState extends ConsumerState<AccountConflictPage> {
  bool _linking = false;

  Future<void> _link(AccountConflict conflict) async {
    setState(() => _linking = true);
    try {
      await ref.read(authControllerProvider.notifier).linkExistingAccount(conflict);
    } catch (e) {
      if (mounted) showAppSnackBar(context, failureMessage(e));
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conflict = widget.conflict;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AuthHeader(
              title: '이미 가입된 이메일이에요',
              subtitle: '이 이메일은 다른 방법으로 가입돼 있어요. '
                  '연결하면 다음부터 ${conflict?.provider.label ?? '소셜 계정'}로도 로그인할 수 있어요.',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                children: [
                  if (conflict != null)
                    SectionCard(
                      title: '기존 계정',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: SectionCard.innerPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(conflict.maskedEmail, style: AppTypography.bodyStrong),
                            const SizedBox(height: 2),
                            Text(conflict.existingMethodLabel, style: AppTypography.meta),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            BottomCta(
              child: Column(
                children: [
                  AppButton(
                    label: '기존 계정과 연결하기',
                    loading: _linking,
                    onPressed: conflict == null ? null : () => _link(conflict),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  AppTextLink(
                    label: '다른 계정으로 로그인',
                    color: AppColors.textSecondary,
                    onPressed: () => context.go(AppRoutes.login),
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
