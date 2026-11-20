import 'package:apt/app/theme/app_colors.dart';
import 'package:apt/app/theme/app_spacing.dart';
import 'package:apt/app/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// 리디자인 v2 토큰 (시안 v2: 흰 바탕, IBM Plex Sans KR, 글자 26 · 18 · 15 · 13)
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('글자 크기는 네 단계(26 · 18 · 15 · 13)이고 캡션도 12 이상', (tester) async {
    expect(AppTypography.display.fontSize, 26);
    expect(AppTypography.section.fontSize, 18);
    expect(AppTypography.body.fontSize, 15);
    expect(AppTypography.meta.fontSize, 13);
    expect(AppTypography.caption.fontSize, greaterThanOrEqualTo(12));
  });

  testWidgets('본문 글자는 잉크색, 흐린 본문은 보조색', (tester) async {
    expect(AppTypography.body.color, AppColors.textPrimary);
    expect(AppTypography.bodyMuted.color, AppColors.textSecondary);
  });

  testWidgets('글꼴은 IBM Plex Sans KR', (tester) async {
    expect(AppTypography.body.fontFamily, contains('IBMPlexSansKR'));
  });

  testWidgets('화면 바탕은 흰색, 채움은 #EEF2F8', (tester) async {
    expect(AppColors.bg, const Color(0xFFFFFFFF));
    expect(AppColors.fill, const Color(0xFFEEF2F8));
  });

  testWidgets('버튼 54 · 작은 버튼 40 · 칩 36 · 구역 띠 10', (tester) async {
    expect(AppSpacing.buttonHeight, 54);
    expect(AppSpacing.smallButtonHeight, 40);
    expect(AppSpacing.chipHeight, 36);
    expect(AppSpacing.sectionGap, 10);
  });
}
