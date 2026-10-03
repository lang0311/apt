import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../error/app_failure.dart';
import 'buttons.dart';
import 'surfaces.dart';

/// 로딩 (선택적으로 단계 메시지)
class AppLoading extends StatelessWidget {
  const AppLoading({super.key, this.message, this.padding = const EdgeInsets.all(AppSpacing.xxl)});
  final String? message;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.md),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(message!, key: ValueKey(message), style: AppTypography.body, textAlign: TextAlign.center),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 스켈레톤 블록
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, required this.height, this.radius = 12});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: AppColors.placeholder, borderRadius: BorderRadius.circular(radius)),
    );
  }
}

/// 리스트용 스켈레톤 (썸네일 + 두 줄)
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 3, this.padding = AppSpacing.screenPadding});
  final int count;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        children: [
          for (var i = 0; i < count; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                child: Row(
                  children: const [
                    SkeletonBox(width: 64, height: 64, radius: 14),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 120, height: 14),
                          SizedBox(height: 10),
                          SkeletonBox(height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 빈 상태 (아이콘 원 + 제목 + 설명 + CTA)
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    this.description,
    this.icon = Icons.bookmark_border_rounded,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.compact = false,
  });

  final String title;
  final String? description;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: compact ? AppSpacing.lg : AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconCircle(icon: icon, size: compact ? 64 : 110),
          SizedBox(height: compact ? AppSpacing.sm : AppSpacing.xl),
          Text(title, style: compact ? AppTypography.cardTitle : AppTypography.title, textAlign: TextAlign.center),
          if (description != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(description!, style: AppTypography.body, textAlign: TextAlign.center),
          ],
          if (actionLabel != null) ...[
            SizedBox(height: compact ? AppSpacing.md : AppSpacing.xl),
            AppButton(label: actionLabel!, onPressed: onAction, expand: !compact),
          ],
          if (secondaryLabel != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton.outline(label: secondaryLabel!, onPressed: onSecondary, icon: Icons.add_rounded),
          ],
        ],
      ),
    );
  }
}

/// 오류 상태 (재시도)
class AppErrorState extends StatelessWidget {
  const AppErrorState({super.key, required this.error, this.onRetry, this.compact = false, this.title});
  final Object error;
  final VoidCallback? onRetry;
  final bool compact;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: compact ? AppSpacing.md : AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconCircle(
            icon: Icons.error_outline_rounded,
            size: compact ? 44 : 64,
            color: AppColors.danger,
            background: AppColors.dangerSoft,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(title ?? '불러오지 못했어요', style: AppTypography.cardTitle, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(failureMessage(error), style: AppTypography.meta, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: '다시 시도',
              onPressed: onRetry,
              variant: AppButtonVariant.soft,
              expand: false,
              height: 44,
              icon: Icons.refresh_rounded,
            ),
          ],
        ],
      ),
    );
  }
}

/// AsyncValue → loading / error / empty / data 공통 처리.
/// refreshing(재요청 중)에는 이전 데이터를 유지한다 (Riverpod 기본 동작).
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.loading,
    this.onRetry,
    this.isEmpty,
    this.empty,
    this.compactError = false,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget? loading;
  final VoidCallback? onRetry;
  final bool Function(T data)? isEmpty;
  final Widget? empty;
  final bool compactError;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: (d) => (isEmpty?.call(d) ?? false) && empty != null ? empty! : data(d),
      loading: () => loading ?? const AppLoading(),
      error: (e, _) => AppErrorState(error: e, onRetry: onRetry, compact: compactError),
    );
  }
}
