import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// 하단 고정 CTA 영역. SafeArea(bottom) 포함.
/// Scaffold(resizeToAvoidBottomInset: true, 기본값)의 bottomNavigationBar 대신
/// body Column 하단에 두면 키보드가 올라와도 가려지지 않는다.
class BottomCta extends StatelessWidget {
  const BottomCta({super.key, required this.child, this.background = AppColors.bg});

  final Widget child;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: background,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.sm, AppSpacing.screenH, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              child,
            ],
          ),
        ),
      ),
    );
  }
}
