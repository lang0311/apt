import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// 공통 입력 필드. 높이 52, radius 15, 흰 배경 + border.
/// 오류: 빨강 테두리 (+ 아래 한 줄 메시지는 [AppFieldError]).
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.suffix,
    this.hasError = false,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.maxLength,
    this.showCounter = false,
    this.autofocus = false,
    this.enabled = true,
    this.fillColor = AppColors.surface,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool hasError;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int? maxLength;
  final bool showCounter;
  final bool autofocus;
  final bool enabled;
  final Color fillColor;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final TextEditingController _controller = widget.controller ?? TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    if (widget.showCounter) _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.hasError
        ? AppColors.danger
        : _focus.hasFocus
            ? AppColors.primary
            : AppColors.border;

    final field = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      constraints: const BoxConstraints(minHeight: AppSpacing.inputHeight),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: widget.fillColor,
        borderRadius: AppRadius.inputAll,
        border: Border.all(color: borderColor, width: widget.hasError || _focus.hasFocus ? 1.4 : 1),
      ),
      child: Row(
        children: [
          if (widget.prefixIcon != null) ...[
            Icon(widget.prefixIcon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              autofocus: widget.autofocus,
              enabled: widget.enabled,
              obscureText: widget.obscureText,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              maxLength: widget.maxLength,
              style: AppTypography.bodyStrong,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                counterText: '',
                hintText: widget.hint,
                hintStyle: AppTypography.bodyStrong.copyWith(color: AppColors.textHint, fontWeight: FontWeight.w500),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          if (widget.showCounter && widget.maxLength != null)
            Text('${_controller.text.characters.length} / ${widget.maxLength}', style: AppTypography.caption),
          if (widget.suffix != null) widget.suffix!,
        ],
      ),
    );

    if (widget.label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label!, style: AppTypography.label),
        const SizedBox(height: AppSpacing.xs),
        field,
      ],
    );
  }
}

/// 필드 아래 한 줄 오류 메시지 (빨강 아이콘 + 문장)
class AppFieldError extends StatelessWidget {
  const AppFieldError(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.danger),
        const SizedBox(width: 6),
        Expanded(child: Text(message, style: AppTypography.meta.copyWith(color: AppColors.danger, fontWeight: FontWeight.w600))),
      ],
    );
  }
}

/// 검색 필드 (pill 모양, 돋보기)
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.hint,
    this.onChanged,
    this.controller,
    this.fillColor = AppColors.surface,
    this.trailing,
    this.bordered = false,
  });

  final String hint;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final Color fillColor;
  final Widget? trailing;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.only(left: AppSpacing.md, right: 6),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(16),
        border: bordered ? Border.all(color: AppColors.border) : null,
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 22),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: AppTypography.bodyStrong,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: AppTypography.body.copyWith(color: AppColors.textHint),
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
