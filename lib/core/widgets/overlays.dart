import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import 'bottom_cta.dart';
import 'buttons.dart';

void showAppSnackBar(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  Duration? duration,
}) {
  final action = actionLabel == null || onAction == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction);
  // 누를 버튼이 있으면 조금 더 오래 둔다
  final shown = duration ?? Duration(seconds: action == null ? 2 : 4);
  final lift = _bottomCtaLift(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      action: action,
      duration: shown,
      // 기본 여백(15, 5, 15, 10)에서 아래만 하단 버튼 위로 올린다
      margin: lift == null ? null : EdgeInsets.fromLTRB(15, 5, 15, lift),
    ));
}

/// 화면에 하단 고정 버튼(BottomCta)이 있으면 스낵바를 그 위(8)로 띄울 아래 여백. 없으면 null.
/// BottomCta는 키보드 때문에 body 안에 두어 Scaffold가 모르므로, 그대로 두면 스낵바가 버튼을 덮는다.
double? _bottomCtaLift(BuildContext context) {
  RenderBox? cta;
  void find(Element element) {
    if (cta != null) return;
    final box = element.widget is BottomCta ? element.renderObject : null;
    if (box is RenderBox && box.attached && box.hasSize) {
      cta = box;
    } else {
      element.visitChildren(find);
    }
  }

  context.visitChildElements(find);
  final box = cta;
  if (box == null) return null;
  final top = box.localToGlobal(Offset.zero).dy;
  // Scaffold는 떠 있는 스낵바를 body 아래 끝(하단 탭이 있으면 그 위)과 화면 안전 영역 중 더 위쪽 기준으로 놓는다.
  // BottomCta는 body 맨 아래에 있으니 그 아래 끝이 body 아래 끝이다.
  final view = MediaQueryData.fromView(View.of(context));
  final base = math.min(top + box.size.height, view.size.height - view.viewPadding.bottom);
  return math.max(10, base - top + AppSpacing.xs);
}

/// 바텀시트 (상단 큰 radius + 핸들). 탭바를 덮도록 root navigator 사용.
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
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
  const SheetAction({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
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
          for (final action in actions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(action.icon, color: AppColors.textPrimary),
              title: Text(action.label, style: AppTypography.bodyStrong),
              onTap: () {
                Navigator.of(ctx).pop();
                action.onTap();
              },
            ),
        ],
      ),
    ),
  );
}
