import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// 색 규칙(07 D57): primary = 화면마다 하나, 다음 단계로 가는 주 행동 · white = 그 옆 보조 행동 ·
/// soft = 목록 줄 안 작은 행동 · dark = 이미 켜진 상태(저장됨 등) · danger = 지우기 · 차단(빨간 글자)
/// v2: 보조(secondary · white)는 채움 바탕 + 잉크 글자, 테두리 없음.
enum AppButtonVariant { primary, dark, soft, white, secondary, danger }

/// 공통 버튼 (Primary / Dark / Soft / Secondary(White) / Danger). 높이 54, radius 14.
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
    // 비활성은 투명도로 흐리지 않고 회색 바탕 + 진한 회색 글자로 (로딩 중에는 원래 색을 유지)
    final (bg, fg, border) = !enabled && !loading
        ? (AppColors.progressInactive, AppColors.disabledText, null)
        : switch (variant) {
            AppButtonVariant.primary => (AppColors.primary, Colors.white, null),
            AppButtonVariant.dark => (AppColors.ink, Colors.white, null),
            AppButtonVariant.soft => (AppColors.primarySoft, AppColors.primary, null),
            AppButtonVariant.white || AppButtonVariant.secondary => (AppColors.fill, AppColors.textPrimary, null),
            AppButtonVariant.danger => (AppColors.fill, AppColors.dangerText, null),
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

    return SizedBox(
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
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppRadius.small),
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
    this.background = AppColors.surface,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
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
        child: SizedBox.square(dimension: size, child: Icon(icon, size: size * 0.55, color: AppColors.textPrimary)),
      ),
    );
    return tooltip == null ? box : Tooltip(message: tooltip!, child: box);
  }
}
