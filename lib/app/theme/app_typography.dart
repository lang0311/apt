import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// 디자인 토큰 — 타이포 (Noto Sans KR). (docs/03_DESIGN_SYSTEM.md §3)
/// 시안의 8.5–10px 텍스트는 가독성을 위해 캡션 11, 본문 13 이상으로 올렸다.
abstract final class AppTypography {
  static TextStyle _s(double size, FontWeight weight,
          {Color color = AppColors.textPrimary, double height = 1.4}) =>
      GoogleFonts.notoSansKr(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: -0.2,
      );

  /// 화면 대제목 (탭 루트, 인증 첫 화면)
  static final display = _s(26, FontWeight.w800, height: 1.3);

  /// 위저드/섹션 큰 제목
  static final title = _s(21, FontWeight.w700, height: 1.35);

  /// 서브 화면 헤더 타이틀
  static final header = _s(20, FontWeight.w700, height: 1.3);

  /// 섹션 제목
  static final section = _s(18, FontWeight.w700, height: 1.35);

  /// 카드 제목
  static final cardTitle = _s(16, FontWeight.w700);

  static final bodyStrong = _s(14, FontWeight.w600);
  static final body = _s(13, FontWeight.w500, color: AppColors.textSecondary);
  static final button = _s(15, FontWeight.w700, height: 1.2);
  static final label = _s(13, FontWeight.w700);

  /// 설명/메타
  static final meta = _s(12, FontWeight.w500, color: AppColors.textSecondary);

  /// 캡션 (최소 11)
  static final caption = _s(11, FontWeight.w500, color: AppColors.textSecondary);

  static final statNumber = _s(28, FontWeight.w800, height: 1.1);
}
