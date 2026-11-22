import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// 공통 입력 필드 (v2). 높이 52(칸 안 이름표가 있으면 58), radius 14, 채움 바탕 · 테두리 없음, 포커스 · 오류는 2px.
/// 오류: 빨강 테두리 (+ 아래 한 줄 메시지는 [AppFieldError]).
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.innerLabel,
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
    this.autofillHints,
  });

  final TextEditingController? controller;
  final String? label;

  /// 칸 안 위쪽의 작은 이름표 (로그인처럼 칸이 무엇인지 늘 보여야 할 때, v2)
  final String? innerLabel;
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

  /// 비밀번호 관리자 자동 입력 (예: [AutofillHints.username]). 붙여넣기는 막지 않는다.
  final Iterable<String>? autofillHints;

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
    final Color borderColor;
    if (widget.hasError) {
      borderColor = AppColors.danger;
    } else if (_focus.hasFocus) {
      borderColor = AppColors.primary;
    } else {
      borderColor = Colors.transparent;
    }

    final field = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      constraints: BoxConstraints(minHeight: widget.innerLabel == null ? AppSpacing.inputHeight : 58),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: widget.hasError || _focus.hasFocus ? AppColors.surface : AppColors.fill,
        borderRadius: AppRadius.inputAll,
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Row(
        children: [
          if (widget.prefixIcon != null) ...[Icon(widget.prefixIcon, size: 20, color: AppColors.textSecondary), const SizedBox(width: AppSpacing.sm)],
          Expanded(
            child: _withInnerLabel(
              TextField(
                controller: _controller,
                focusNode: _focus,
                autofocus: widget.autofocus,
                enabled: widget.enabled,
                obscureText: widget.obscureText,
                keyboardType: widget.keyboardType,
                textInputAction: widget.textInputAction,
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
                autofillHints: widget.autofillHints,
                maxLength: widget.maxLength,
                style: AppTypography.bodyStrong,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  counterText: '',
                  hintText: widget.hint,
                  hintStyle: AppTypography.bodyStrong.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                  contentPadding: EdgeInsets.symmetric(vertical: widget.innerLabel == null ? 16 : 4),
                ),
              ),
            ),
          ),
          if (widget.showCounter && widget.maxLength != null) Text('${_controller.text.characters.length} / ${widget.maxLength}', style: AppTypography.caption),
          if (widget.suffix != null) widget.suffix!,
        ],
      ),
    );

    if (widget.label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label!, style: AppTypography.labelLarge.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.xs),
        field,
      ],
    );
  }

  Widget _withInnerLabel(Widget input) {
    if (widget.innerLabel == null) return input;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.innerLabel!, style: AppTypography.caption),
          input,
        ],
      ),
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
        Expanded(
          child: Text(
            message,
            style: AppTypography.meta.copyWith(color: AppColors.dangerText, fontWeight: FontWeight.w500),
          ),
        ),
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
    this.focusNode,
    this.autofocus = false,
    this.onSubmitted,
  });

  final String hint;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final Color fillColor;
  final Widget? trailing;
  final bool bordered;
  final FocusNode? focusNode;
  final bool autofocus;

  /// 키보드의 검색 버튼
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.only(left: AppSpacing.md, right: 6),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: bordered ? Border.all(color: AppColors.border) : null,
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 22),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: autofocus,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              style: AppTypography.bodyStrong,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: AppTypography.bodyMuted.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
