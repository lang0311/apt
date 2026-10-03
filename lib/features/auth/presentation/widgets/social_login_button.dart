import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/auth_models.dart';

/// 카카오(노랑) / Google(흰) / Apple(검정) 로그인 버튼
class SocialLoginButton extends StatelessWidget {
  const SocialLoginButton({super.key, required this.provider, required this.onPressed, this.loading = false});

  final SocialProvider provider;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (provider) {
      SocialProvider.kakao => (AppColors.kakao, const Color(0xFF191919), null),
      SocialProvider.google => (AppColors.surface, AppColors.textPrimary, AppColors.border),
      SocialProvider.apple => (AppColors.ink, Colors.white, null),
    };
    final Widget leading = switch (provider) {
      SocialProvider.kakao => Icon(Icons.chat_bubble_rounded, color: fg, size: 20),
      SocialProvider.google => Text('G', style: AppTypography.cardTitle.copyWith(color: const Color(0xFF4285F4), fontSize: 19)),
      SocialProvider.apple => Icon(Icons.apple, color: fg, size: 24),
    };

    return SizedBox(
      height: AppSpacing.buttonHeight,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: border == null ? BorderSide.none : BorderSide(color: border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: loading ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                SizedBox(width: 24, child: Center(child: leading)),
                Expanded(
                  child: Center(
                    child: loading
                        ? SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
                        : Text('${provider.label}로 계속하기', style: AppTypography.button.copyWith(color: fg)),
                  ),
                ),
                const SizedBox(width: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
