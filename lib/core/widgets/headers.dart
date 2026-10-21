import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import 'buttons.dart';

void _defaultBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/home');
  }
}

/// 탭 루트 화면 상단: 큰 제목 + 설명 + 우측 액션 (홈·코스·저장됨·추출·마이)
class PageTitleHeader extends StatelessWidget {
  const PageTitleHeader({super.key, required this.title, this.subtitle, this.trailing, this.overline});

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final String? overline;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, AppSpacing.md),
      child: Row(
        // 제목 한 줄만 있으면 오른쪽 버튼과 가운데를 맞춘다
        crossAxisAlignment: subtitle == null && overline == null ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (overline != null) ...[
                  Text(overline!, style: AppTypography.cardTitle),
                  const SizedBox(height: 4),
                ],
                Text(title, style: AppTypography.display),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: AppTypography.body),
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

/// 서브 화면 헤더: 36×36 흰 뒤로 버튼 + 20px 타이틀 + 우측 액션
class SubPageHeader extends StatelessWidget {
  const SubPageHeader({super.key, required this.title, this.trailing, this.onBack, this.showBack = true});

  final String title;
  final Widget? trailing;
  final VoidCallback? onBack;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.screenH, AppSpacing.sm),
      child: Row(
        children: [
          if (showBack) ...[
            AppIconBox(
              icon: Icons.chevron_left_rounded,
              tooltip: '뒤로',
              onPressed: onBack ?? () => _defaultBack(context),
            ),
            const SizedBox(width: AppSpacing.sm),
          ] else
            const SizedBox(width: 4),
          Expanded(
            child: Text(title, style: AppTypography.header, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 배경 없는 아이콘 헤더: 왼쪽 아이콘(뒤로/닫기) + 제목 17 + 오른쪽 아이콘들. 누르는 영역은 48.
/// 코스 화면(상세 · 편집 · 만들기)에서 쓴다.
class PlainHeader extends StatelessWidget {
  const PlainHeader({
    super.key,
    this.title,
    this.leadingIcon = Icons.chevron_left_rounded,
    this.leadingTooltip = '뒤로',
    this.onLeading,
    this.actions = const [],
    this.trailing,
  });

  final String? title;
  final IconData leadingIcon;
  final String leadingTooltip;
  final VoidCallback? onLeading;
  final List<Widget> actions;

  /// 오른쪽 끝 글자 (예: 3 / 4)
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xxs, AppSpacing.xxs, AppSpacing.xs, AppSpacing.xxs),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            IconButton(
              tooltip: leadingTooltip,
              onPressed: onLeading ?? () => _defaultBack(context),
              icon: Icon(leadingIcon, size: leadingIcon == Icons.chevron_left_rounded ? 30 : 24, color: AppColors.textPrimary),
            ),
            Expanded(
              child: title == null
                  ? const SizedBox()
                  : Text(title!, style: AppTypography.header.copyWith(fontSize: 17, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            ...actions,
            if (trailing != null) Padding(padding: const EdgeInsets.only(right: AppSpacing.sm), child: trailing),
          ],
        ),
      ),
    );
  }
}

/// 인증 화면: 테두리 없는 뒤로 아이콘 + 큰 제목 + 설명
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.title, this.subtitle, this.showBack = true, this.onBack});

  final String title;
  final String? subtitle;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    // 부모 Column이 가운데 정렬이어도 왼쪽에 붙도록 폭을 채운다
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.xs, AppSpacing.screenH, AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showBack)
              IconButton(
                onPressed: onBack ?? () => _defaultBack(context),
                icon: const Icon(Icons.chevron_left_rounded, size: 32, color: AppColors.textPrimary),
                tooltip: '뒤로',
              )
            else
              const SizedBox(height: 48),
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.display),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(subtitle!, style: AppTypography.body),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 코스 만들기 위저드 헤더: 뒤로 + 타이틀 + n/4 + 4분할 진행 바
class StepHeader extends StatelessWidget {
  const StepHeader({super.key, required this.title, required this.step, this.total = 4, this.onBack, this.trailing});

  final String title;
  final int step;
  final int total;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SubPageHeader(
          title: title,
          onBack: onBack,
          trailing: trailing ??
              Text('$step / $total', style: AppTypography.label.copyWith(color: AppColors.textSecondary)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH + 4),
          child: StepProgressBar(step: step, total: total),
        ),
      ],
    );
  }
}

class StepProgressBar extends StatelessWidget {
  const StepProgressBar({super.key, required this.step, this.total = 4});
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$total단계 중 $step단계',
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: i < step ? AppColors.primary : AppColors.progressInactive,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 섹션 제목 + 우측 액션("전체 보기 ›") 또는 보조 텍스트("4개")
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.trailingText,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xl, AppSpacing.screenH, AppSpacing.sm),
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? trailingText;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppTypography.section)),
          if (trailing != null) trailing!,
          if (trailingText != null) Text(trailingText!, style: AppTypography.label.copyWith(color: AppColors.textSecondary)),
          if (actionLabel != null)
            AppTextLink(
              label: actionLabel!,
              onPressed: onAction,
              color: AppColors.textSecondary,
              style: AppTypography.meta,
              trailingChevron: true,
            ),
        ],
      ),
    );
  }
}
