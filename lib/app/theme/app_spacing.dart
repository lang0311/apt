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

  static const buttonHeight = 54.0;
  static const smallButtonHeight = 40.0;
  static const inputHeight = 52.0;
  static const chipHeight = 36.0;

  /// 구역 사이 채움 띠 높이 (v2)
  static const sectionGap = 10.0;
  static const backButtonSize = 36.0;
}

/// 디자인 토큰 — 모서리. 크기에 따라 네 단계 + 알약 (UI 리뷰 디자인 언어 ①, 07 D56)
/// 작게 10(썸네일 · 아이콘 칸 · 태그) · 중간 14(입력칸 · 버튼 · 사진 · 카드 안 타일) · 크게 20(카드) · 시트 28 · 알약 999.
/// 작은 태그 · 모자이크 칸 · 체크박스는 `tiny` 6, 진행 막대 · 손잡이처럼 선에 가까운 것(2~3)만 숫자를 그대로 쓴다.
abstract final class AppRadius {
  static const tiny = 6.0;
  static const small = 10.0;
  static const medium = 14.0;
  static const large = 20.0;
  static const sheet = 24.0; // v2 시안 .sheet 위 모서리 24
  static const pill = 999.0;

  // 예전 이름 — 위 네 단계로 모았다
  static const xs = small;
  static const sm = small;
  static const input = medium;
  static const button = medium;
  static const thumb = medium;
  static const card = large;

  static final inputAll = BorderRadius.circular(input);
  static final buttonAll = BorderRadius.circular(button);
  static final cardAll = BorderRadius.circular(card);
  static final pillAll = BorderRadius.circular(pill);
}

/// 디자인 토큰 — 그림자 (카드는 거의 없음, 떠 있는 요소만)
abstract final class AppShadow {
  /// 떠 있는 요소(지도 위 유리 칸 · 버튼) — v2 시안 .glass: 0 2px 10px 10%
  static const soft = [
    BoxShadow(color: Color(0x1A14181E), blurRadius: 10, offset: Offset(0, 2)),
  ];

  /// 아래 시트 위쪽 그림자 — v2 시안 .sheet: 0 -4px 20px 8%
  static const sheet = [
    BoxShadow(color: Color(0x1414181E), blurRadius: 20, offset: Offset(0, -4)),
  ];
}
