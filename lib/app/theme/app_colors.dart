import 'package:flutter/material.dart';

/// 디자인 토큰 — 색상. (docs/03_DESIGN_SYSTEM.md §3)
/// 화면마다 임의 색을 만들지 않고 여기 값만 사용한다.
abstract final class AppColors {
  static const primary = Color(0xFF246BFD);
  static const primarySoft = Color(0xFFEDF3FF);
  static const primarySoftStrong = Color(0xFFDCE8FF);

  static const textPrimary = Color(0xFF132238);
  static const textSecondary = Color(0xFF7B8AA3);
  static const textHint = Color(0xFF98A3B5);

  static const ink = Color(0xFF14223A);

  static const bg = Color(0xFFF6F8FC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFEEF2F8);

  static const border = Color(0xFFE4EAF3);
  static const divider = Color(0xFFE9EEF5);
  static const progressInactive = Color(0xFFDCE4F0);

  /// AI 추천 전용. AI가 추천한 것에만 쓴다.
  static const ai = Color(0xFFF39A45);
  static const aiSoft = Color(0xFFFFF1E4);

  static const danger = Color(0xFFF0645A);
  static const dangerSoft = Color(0xFFFDECEB);
  static const success = Color(0xFF16A07D);
  static const successSoft = Color(0xFFE6F6F1);

  /// 추출 계열 보조(보라)
  static const extract = Color(0xFF8A63E6);
  static const extractSoft = Color(0xFFF1ECFD);

  static const kakao = Color(0xFFFEE500);
  static const kakaoSoft = Color(0xFFFFF3D6);

  static const scrim = Color(0x8014223A);
  static const placeholder = Color(0xFFE3E9F2);
}
