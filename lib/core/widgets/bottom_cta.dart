import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// 하단 고정 CTA 영역. SafeArea(bottom) 포함.
/// Scaffold(resizeToAvoidBottomInset: true, 기본값)의 bottomNavigationBar 대신
/// body Column 하단에 두면 키보드가 올라와도 가려지지 않는다.
class BottomCta extends StatelessWidget {
  const BottomCta({super.key, required this.child, this.caption, this.background = AppColors.bg});

  final Widget child;
  final String? caption;
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
              if (caption != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(caption!, style: AppTypography.caption, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 스크롤 본문 + 하단 고정 CTA 레이아웃
class ScrollWithBottomCta extends StatelessWidget {
  const ScrollWithBottomCta({
    super.key,
    required this.header,
    required this.children,
    required this.cta,
    this.padding = const EdgeInsets.fromLTRB(AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.xl),
  });

  final Widget? header;
  final List<Widget> children;
  final Widget cta;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (header != null) header!,
        Expanded(
          child: ListView(padding: padding, children: children),
        ),
        cta,
      ],
    );
  }
}
