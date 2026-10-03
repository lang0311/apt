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

  Future<void> _link(AccountConflict c) async {
    setState(() => _linking = true);
    try {
      await ref.read(authControllerProvider.notifier).linkExistingAccount(c);
    } catch (e) {
      if (mounted) showAppSnackBar(context, failureMessage(e));
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.conflict;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AuthHeader(title: '계정 연결 확인'),
            Expanded(
              child: ListView(
                padding: AppSpacing.screenPadding,
                children: [
                  const SizedBox(height: AppSpacing.lg),
                  StatusCard(
                    icon: Icons.priority_high_rounded,
                    title: '이미 가입된 이메일이에요',
                    description: '기존 계정과 ${c?.provider.label ?? '소셜'} 계정을 연결할까요?',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (c != null)
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.maskedEmail, style: AppTypography.cardTitle.copyWith(fontSize: 17)),
                          const SizedBox(height: 4),
                          Text(c.existingMethodLabel, style: AppTypography.body),
                          const SizedBox(height: AppSpacing.md),
                          Text('연결하면 다음부터 ${c.provider.label}로 로그인할 수 있어요.', style: AppTypography.meta),
                        ],
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
                    onPressed: c == null ? null : () => _link(c),
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
