import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// 섹션 묶음 (surface + border 1px, radius 20). 제목은 컨테이너 안에 둔다.
/// [child]는 좌우 여백 없이 받는다 — 가로 스크롤 목록이 컨테이너 끝까지 닿게 하고, 여백은 child가 정한다.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child, this.actionLabel, this.onAction, this.trailing});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// 제목 줄 오른쪽 위젯 (예: 필터, '+ 새 보관함'). [actionLabel]보다 우선한다.
  final Widget? trailing;
  final Widget child;

  static const innerPadding = AppSpacing.md;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.xs, 0, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(innerPadding, 0, trailing != null ? AppSpacing.xs : AppSpacing.xxs, AppSpacing.xxs),
            child: Row(
              children: [
                // 오른쪽 버튼이 없어도 제목 줄 높이(44)를 같게 유지한다
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Semantics(header: true, child: Text(title, style: AppTypography.cardTitle)),
                    ),
                  ),
                ),
                if (trailing != null)
                  trailing!
                else if (actionLabel != null)
                  TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary, minimumSize: const Size(44, 44)),
                    child: Text(actionLabel!, style: AppTypography.meta),
                  ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// SectionCard 안의 행 목록. 행 사이에만 구분선을 넣고, 선은 사진 오른쪽(왼쪽 [indent])부터 시작한다.
class DividedRows extends StatelessWidget {
  const DividedRows({super.key, required this.children, this.indent = 88});
  final List<Widget> children;
  final double indent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: 1, indent: indent, color: AppColors.divider),
          children[i],
        ],
      ],
    );
  }
}

/// 카드 (surface, radius 20, border 1px, 그림자 없음)
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.color = AppColors.surface,
    this.onTap,
    this.radius = AppRadius.card,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: const BorderSide(color: AppColors.border),
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

/// primarySoft 배경 안내 카드 (제목 + 설명)
class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.title,
    this.description,
    this.titleColor = AppColors.textPrimary,
  });

  final String title;
  final String? description;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.primarySoft,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
        ],
      ),
    );
  }
}

