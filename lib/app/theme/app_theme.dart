import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        error: AppColors.danger,
        surface: AppColors.surface,
        // fromSeed가 만드는 분홍(tertiary)·연보라(surfaceContainer)가 기본 위젯에 드러나지 않게 앱 색으로 고정
        secondaryContainer: AppColors.primarySoft,
        onSecondaryContainer: AppColors.primary,
        tertiary: AppColors.primary,
        onTertiary: Colors.white,
        tertiaryContainer: AppColors.primarySoft,
        onTertiaryContainer: AppColors.primary,
        surfaceContainerLowest: AppColors.surface,
        surfaceContainerLow: AppColors.surface,
        surfaceContainer: AppColors.surface,
        surfaceContainerHigh: AppColors.surface,
        surfaceContainerHighest: AppColors.surfaceMuted,
      ),
      scaffoldBackgroundColor: AppColors.bg,
    );
    return base.copyWith(
      textTheme: GoogleFonts.ibmPlexSansKrTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.divider, space: 1, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.toast,
        contentTextStyle: AppTypography.labelLarge.copyWith(color: Colors.white, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.inputAll),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.progressInactive,
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        headerForegroundColor: AppColors.textPrimary,
        dividerColor: AppColors.divider,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
        dayPeriodColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.primarySoft : AppColors.surface,
        ),
        dayPeriodTextColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.textSecondary,
        ),
        dayPeriodBorderSide: const BorderSide(color: AppColors.border),
        hourMinuteColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.primarySoft : AppColors.surfaceMuted,
        ),
        hourMinuteTextColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.textPrimary,
        ),
        dialBackgroundColor: AppColors.surfaceMuted,
        dialHandColor: AppColors.primary,
      ),
      textSelectionTheme: const TextSelectionThemeData(cursorColor: AppColors.primary),
      // iOS · 토스 느낌: 퍼지는 물결 없이 누르는 동안 옅은 회색, 화면은 옆으로 밀리고 밀어서 뒤로 가기 (2026-11-23)
      // 머티리얼 그림자(elevation)를 시안처럼 옅고 넓게 보이도록 기본 그림자 색을 연하게
      shadowColor: const Color(0x3314181E),
      splashFactory: NoSplash.splashFactory,
      highlightColor: AppColors.pressed,
      splashColor: Colors.transparent,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
