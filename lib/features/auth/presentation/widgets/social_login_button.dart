import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/brand_marks.dart';
import '../../domain/auth_models.dart';

/// 간편 로그인 아이콘 버튼: 카카오(노랑 원 + 공식 말풍선) / Google(흰 원 + 공식 G) / Apple(검정 원).
/// 누르는 영역 48, 화면 낭독기 이름은 "○○로 로그인".
class SocialIconButton extends StatelessWidget {
  const SocialIconButton({super.key, required this.provider, required this.onPressed, this.loading = false});

  final SocialProvider provider;
  final VoidCallback? onPressed;
  final bool loading;

  static const size = 48.0;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (provider) {
      SocialProvider.kakao => (AppColors.kakao, const Color(0xFF191919), null),
      SocialProvider.google => (AppColors.surfaceRaised, AppColors.textPrimary, AppColors.border),
      SocialProvider.apple => (AppColors.ink, Colors.white, null),
    };
    final Widget icon = switch (provider) {
      SocialProvider.kakao => const KakaoSymbol(size: 22),
      SocialProvider.google => const GoogleMark(size: 20),
      SocialProvider.apple => Icon(Icons.apple, color: fg, size: 26),
    };
    final label = '${provider.label}로 로그인';

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: Material(
          color: bg,
          shape: CircleBorder(side: border == null ? BorderSide.none : BorderSide(color: border)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: loading ? null : onPressed,
            child: SizedBox.square(
              dimension: size,
              child: Center(
                child: loading ? SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg)) : icon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
