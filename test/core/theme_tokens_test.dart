import 'dart:io';

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

  test('화면 코드는 글자 크기를 숫자로 덮어쓰지 않는다 (07 D63, 토큰만 · 위젯 크기 비례는 예외)', () {
    final literal = RegExp(r'fontSize:\s*\d');
    final offenders = [
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.dart') && !f.path.replaceAll(r'\', '/').contains('lib/app/theme/'))
          for (final (i, line) in f.readAsLinesSync().indexed)
            if (literal.hasMatch(line)) '${f.path}:${i + 1}',
    ];
    expect(offenders, isEmpty);
  });

  testWidgets('v2 보조 크기 토큰: 14 · 17 · 20 · 34', (tester) async {
    expect(AppTypography.labelLarge.fontSize, 14);
    expect(AppTypography.bodySmall.fontSize, 14);
    expect(AppTypography.lead.fontSize, 17);
    expect(AppTypography.cardHero.fontSize, 20);
    expect(AppTypography.ddayLarge.fontSize, 34);
  });
}
