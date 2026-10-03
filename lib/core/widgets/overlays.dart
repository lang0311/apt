import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import 'buttons.dart';

void showAppSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
}

/// 바텀시트 (상단 큰 radius + 핸들). 탭바를 덮도록 root navigator 사용.
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: isScrollControlled,
    backgroundColor: AppColors.surface,
    barrierColor: AppColors.scrim,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
    ),
    builder: (ctx) => Padding(
      // 키보드가 올라오면 시트도 함께 올라간다.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            Flexible(child: builder(ctx)),
          ],
        ),
      ),
    ),
  );
}

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      width: 44,
      height: 5,
      decoration: BoxDecoration(color: AppColors.progressInactive, borderRadius: BorderRadius.circular(3)),
    );
  }
}

/// 가운데 모달 카드 (제목 + 닫기 X). 새 보관함 만들기, 파티원 초대.
Future<T?> showAppModal<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required WidgetBuilder builder,
}) {
  return showDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierColor: AppColors.scrim,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: AppSpacing.xl),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sheet)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(title, style: AppTypography.title)),
                AppIconBox(
                  icon: Icons.close_rounded,
                  background: AppColors.bg,
                  tooltip: '닫기',
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle, style: AppTypography.meta),
            ],
            const SizedBox(height: AppSpacing.lg),
            builder(ctx),
          ],
        ),
      ),
    ),
  );
}

/// 확인 다이얼로그 (이탈 확인 등)
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = '확인',
  String cancelLabel = '취소',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    barrierColor: AppColors.scrim,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: AppTypography.cardTitle, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(message, style: AppTypography.meta, textAlign: TextAlign.center),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: cancelLabel,
                    variant: AppButtonVariant.white,
                    height: 46,
                    onPressed: () => Navigator.of(ctx).pop(false),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: AppButton(
                    label: confirmLabel,
                    variant: destructive ? AppButtonVariant.dark : AppButtonVariant.primary,
                    height: 46,
                    onPressed: () => Navigator.of(ctx).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}

/// 액션 시트 항목
class SheetAction {
  const SheetAction({required this.label, required this.icon, required this.onTap, this.destructive = false});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;
}

Future<void> showActionSheet(BuildContext context, {String? title, required List<SheetAction> actions}) {
  return showAppBottomSheet<void>(
    context,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xs, AppSpacing.screenH, AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Text(title, style: AppTypography.cardTitle),
            ),
          for (final a in actions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(a.icon, color: a.destructive ? AppColors.danger : AppColors.textPrimary),
              title: Text(
                a.label,
                style: AppTypography.bodyStrong.copyWith(color: a.destructive ? AppColors.danger : null),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                a.onTap();
              },
            ),
        ],
      ),
    ),
  );
}
