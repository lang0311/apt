import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// 흰 카드 (radius 20, 그림자 없음)
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.color = AppColors.surface,
    this.onTap,
    this.borderColor,
    this.radius = AppRadius.card,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final VoidCallback? onTap;
  final Color? borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: borderColor == null ? BorderSide.none : BorderSide(color: borderColor!, width: 1.4),
    );
    return Material(
      color: color,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// 아이콘 원 (안내 카드, 통계 타일, 보관함 행)
class IconCircle extends StatelessWidget {
  const IconCircle({
    super.key,
    required this.icon,
    this.size = 44,
    this.color = AppColors.primary,
    this.background = AppColors.primarySoft,
  });

  final IconData icon;
  final double size;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

/// primarySoft 배경 안내 카드 (아이콘 + 제목 + 설명)
class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.title,
    this.description,
    this.icon,
    this.iconColor = AppColors.primary,
    this.titleColor = AppColors.textPrimary,
    this.background = AppColors.primarySoft,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? description;
  final IconData? icon;
  final Color iconColor;
  final Color titleColor;
  final Color background;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: background,
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.cardTitle.copyWith(color: titleColor)),
                if (description != null) ...[
                  const SizedBox(height: 4),
                  Text(description!, style: AppTypography.meta),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 상태 안내 카드 — 아이콘 원 + 제목 + 설명 (계정 충돌, 인증 오류, 가입 완료)
class StatusCard extends StatelessWidget {
  const StatusCard({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.iconColor = AppColors.primary,
    this.iconBackground = AppColors.primarySoft,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Color iconColor;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            IconCircle(icon: icon, size: 40, color: iconColor, background: iconBackground),
            const SizedBox(height: AppSpacing.sm),
            Text(title, style: AppTypography.cardTitle.copyWith(fontSize: 17), textAlign: TextAlign.center),
            if (description != null) ...[
              const SizedBox(height: 6),
              Text(description!, style: AppTypography.meta, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}
