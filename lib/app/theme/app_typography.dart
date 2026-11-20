import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// 디자인 토큰 — 타이포 (IBM Plex Sans KR, 리디자인 v2). (docs/03_DESIGN_SYSTEM.md §3)
/// 크기는 네 단계: 제목 26 · 섹션 18 · 본문 15 · 보조 13 (캡션 최소 12).
abstract final class AppTypography {
  static TextStyle _s(double size, FontWeight weight,
          {Color color = AppColors.textPrimary, double height = 1.45}) =>
      GoogleFonts.ibmPlexSansKr(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: -0.2,
      );

  /// 화면 대제목 (탭 루트 · 질문형 제목 · 인증 첫 화면)
  static final display = _s(26, FontWeight.w700, height: 1.28);

  /// 화면의 주인공 제목 (코스 이름 · 장소 이름 · 홈 코스 카드 D-day · 마이 숫자)
  static final hero = _s(24, FontWeight.w700, height: 1.3);

  /// 위저드/큰 제목 (display보다 한 단계 작게 쓸 때)
  static final title = _s(24, FontWeight.w700, height: 1.3);

  /// 서브 화면 헤더 타이틀
  static final header = _s(17, FontWeight.w600, height: 1.3);

  /// 섹션 제목
  static final section = _s(18, FontWeight.w700, height: 1.3);

  /// 카드 · 묶음 제목
  static final cardTitle = _s(16, FontWeight.w700, height: 1.35);

  /// 행 이름 · 강조 본문
  static final bodyStrong = _s(15, FontWeight.w600);

  /// 본문
  static final body = _s(15, FontWeight.w400);

  /// 설명 문장 (제목 아래 한 줄 등)
  static final bodyMuted = _s(15, FontWeight.w400, color: AppColors.textSecondary);
  static final button = _s(16, FontWeight.w600, height: 1.2);
  static final label = _s(13, FontWeight.w600);

  /// 설명/메타 (행의 둘째 줄 · 개수)
  static final meta = _s(13, FontWeight.w400, color: AppColors.textTertiary);

  /// 캡션 (최소 12)
  static final caption = _s(12, FontWeight.w400, color: AppColors.textTertiary);
}
