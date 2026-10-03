import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

enum AppButtonVariant { primary, dark, outline, soft, white }

/// 공통 버튼 (Primary / Dark / Outline / Soft / White). 높이 52, radius 16.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.height = AppSpacing.buttonHeight,
  });

  const AppButton.dark({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.height = AppSpacing.buttonHeight,
  }) : variant = AppButtonVariant.dark;

  const AppButton.outline({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.height = AppSpacing.buttonHeight,
  }) : variant = AppButtonVariant.outline;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool expand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final (bg, fg, border) = switch (variant) {
      AppButtonVariant.primary => (AppColors.primary, Colors.white, null),
      AppButtonVariant.dark => (AppColors.ink, Colors.white, null),
      AppButtonVariant.outline => (AppColors.surface, AppColors.primary, AppColors.primary),
      AppButtonVariant.soft => (AppColors.primarySoft, AppColors.primary, null),
      AppButtonVariant.white => (AppColors.surface, AppColors.textPrimary, AppColors.border),
    };

    final child = loading
        ? SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 20, color: fg), const SizedBox(width: 8)],
              Flexible(
                child: Text(
                  label,
                  style: AppTypography.button.copyWith(color: fg),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    return Opacity(
      opacity: enabled || loading ? 1 : 0.4,
      child: SizedBox(
        height: height,
        width: expand ? double.infinity : null,
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.buttonAll,
            side: border == null ? BorderSide.none : BorderSide(color: border, width: 1.4),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// 텍스트 링크 버튼 (예: "다른 계정으로 로그인", "모두 선택")
class AppTextLink extends StatelessWidget {
  const AppTextLink({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.primary,
    this.style,
    this.trailingChevron = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final TextStyle? style;
  final bool trailingChevron;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: (style ?? AppTypography.label).copyWith(color: color),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (trailingChevron) Icon(Icons.chevron_right_rounded, size: 18, color: color),
          ],
        ),
      ),
    );
  }
}

/// 36×36(기본) 흰 배경 radius 12 아이콘 버튼 — 서브 화면 뒤로가기, 헤더 액션
class AppIconBox extends StatelessWidget {
  const AppIconBox({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = AppSpacing.backButtonSize,
    this.color = AppColors.textPrimary,
    this.background = AppColors.surface,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color color;
  final Color background;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final box = Material(
      color: background,
      borderRadius: BorderRadius.circular(size / 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(size / 3),
        onTap: onPressed,
        child: SizedBox.square(dimension: size, child: Icon(icon, size: size * 0.55, color: color)),
      ),
    );
    return tooltip == null ? box : Tooltip(message: tooltip!, child: box);
  }
}

/// 플로팅 다크 pill 버튼 — "지도에서 보기"
class FloatingPillButton extends StatelessWidget {
  const FloatingPillButton({super.key, required this.label, required this.icon, required this.onPressed});

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: AppRadius.pillAll, boxShadow: AppShadow.floating),
      child: Material(
        color: AppColors.ink,
        borderRadius: AppRadius.pillAll,
        child: InkWell(
          borderRadius: AppRadius.pillAll,
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Text(label, style: AppTypography.button.copyWith(color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
