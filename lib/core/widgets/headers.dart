import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import 'buttons.dart';

void _defaultBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(AppRoutes.home);
  }
}

/// 탭 루트 화면 상단: 큰 제목 + 우측 액션 (홈·코스·저장됨·추출·마이)
class PageTitleHeader extends StatelessWidget {
  const PageTitleHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, AppSpacing.md),
      child: Row(
        // 제목과 오른쪽 버튼의 가운데를 맞춘다
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.display),
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
  const SubPageHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.screenH, AppSpacing.sm),
      child: Row(
        children: [
          AppIconBox(
            icon: Icons.chevron_left_rounded,
            tooltip: '뒤로',
            onPressed: () => _defaultBack(context),
          ),
          const SizedBox(width: AppSpacing.sm),
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
                  : Text(
                      title!,
                      style: AppTypography.header.copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
  const AuthHeader({super.key, required this.title, this.subtitle, this.onBack});

  final String title;
  final String? subtitle;
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
            IconButton(
              onPressed: onBack ?? () => _defaultBack(context),
              icon: const Icon(Icons.chevron_left_rounded, size: 32, color: AppColors.textPrimary),
              tooltip: '뒤로',
            ),
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

/// 코스 만들기 위저드 헤더: 배경 없는 뒤로 + "코스 만들기" + n / 4 + 4분할 진행 바 (1–4단계 같은 모양)
class StepHeader extends StatelessWidget {
  const StepHeader({super.key, required this.step, this.onBack});

  final int step;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PlainHeader(
          title: '코스 만들기',
          onLeading: onBack,
          trailing: Text(
            '$step / 4',
            style: AppTypography.label.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: StepProgressBar(step: step),
        ),
      ],
    );
  }
}

class StepProgressBar extends StatelessWidget {
  const StepProgressBar({super.key, required this.step});
  final int step;

  static const _total = 4;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$_total단계 중 $step단계',
      child: Row(
        children: [
          for (var i = 0; i < _total; i++) ...[
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

/// 섹션 제목 + 우측 위젯 또는 보조 텍스트("4곳")
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailingText,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xl, AppSpacing.screenH, AppSpacing.sm),
  });

  final String title;
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
        ],
      ),
    );
  }
}
