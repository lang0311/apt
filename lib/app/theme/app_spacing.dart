import 'package:flutter/material.dart';

/// 디자인 토큰 — 간격 스케일 4 · 8 · 12 · 16 · 20 · 24 · 32
abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// 화면 좌우 여백. 폭은 하드코딩하지 않고 이 여백 + 늘어나는 콘텐츠로 구성한다.
  static const screenH = lg;
  static const screenPadding = EdgeInsets.symmetric(horizontal: screenH);

  static const buttonHeight = 52.0;
  static const inputHeight = 52.0;
  static const chipHeight = 34.0;
  static const backButtonSize = 36.0;
}

/// 디자인 토큰 — 모서리
abstract final class AppRadius {
  static const sm = 12.0;
  static const input = 15.0;
  static const button = 16.0;
  static const thumb = 14.0;
  static const card = 20.0;
  static const sheet = 28.0;
  static const pill = 999.0;

  static final inputAll = BorderRadius.circular(input);
  static final buttonAll = BorderRadius.circular(button);
  static final thumbAll = BorderRadius.circular(thumb);
  static final cardAll = BorderRadius.circular(card);
  static final pillAll = BorderRadius.circular(pill);
}

/// 디자인 토큰 — 그림자 (카드는 거의 없음, 플로팅 요소만)
abstract final class AppShadow {
  static const floating = [
    BoxShadow(color: Color(0x2914223A), blurRadius: 18, offset: Offset(0, 6)),
  ];
  static const soft = [
    BoxShadow(color: Color(0x0F14223A), blurRadius: 12, offset: Offset(0, 2)),
  ];
}
