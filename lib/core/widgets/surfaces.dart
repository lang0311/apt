import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// 섹션 묶음 (v2: 상자 없이 굵은 제목 18 + 내용). 구역 사이는 [SectionGap] 띠로 나눈다.
/// [child]는 좌우 여백 없이 받는다 — 가로 스크롤 목록이 컨테이너 끝까지 닿게 하고, 여백은 child가 정한다.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
    this.trailing,
    this.titleWidget,
    this.boxed = false,
  });

  final String title;

  /// 제목 글자 대신 넣는 위젯 (예: 저장됨 선택 모드의 '전체 선택'). [title]은 그대로 의미로 남긴다.
  final Widget? titleWidget;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// 제목 줄 오른쪽 위젯 (예: 필터, '+ 새 보관함'). [actionLabel]보다 우선한다.
  final Widget? trailing;
  final Widget child;

  /// 일정 카드처럼 흰 바탕 + 1px 선(모서리 20)으로 묶어야 할 때 (v2 추천 결과 · 코스 상세, 사용자가 휑하지 않게 요청)
  final bool boxed;

  static const innerPadding = AppSpacing.md;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: boxed
          ? BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider),
            )
          : null,
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
                      child: titleWidget ?? Semantics(header: true, child: Text(title, style: AppTypography.section)),
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

/// 구역 사이 채움 띠 (v2, 높이 10)
class SectionGap extends StatelessWidget {
  const SectionGap({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: AppSpacing.sectionGap,
    width: double.infinity,
    child: ColoredBox(color: AppColors.fill),
  );
}

/// SectionCard 안의 행 목록. 행 사이에만 구분선을 넣고, 선은 사진 오른쪽(왼쪽 [indent])부터 시작한다.
class DividedRows extends StatelessWidget {
  const DividedRows({super.key, required this.children, this.indent = 88, this.endIndent = AppSpacing.md});
  final List<Widget> children;
  final double indent;

  /// 구분선 오른쪽 여백 — 카드 안쪽 여백과 맞춰 카드 끝까지 뻗지 않게
  final double endIndent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          // v2: 행 사이는 선 없이 여백으로만 나눈다 (높이 1은 남겨 행 위치가 흔들리지 않게)
          if (i > 0) const SizedBox(height: 1),
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
