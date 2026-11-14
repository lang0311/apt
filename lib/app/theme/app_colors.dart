import 'package:flutter/material.dart';

/// 디자인 토큰 — 색상. (docs/03_DESIGN_SYSTEM.md §3)
/// 화면마다 임의 색을 만들지 않고 여기 값만 사용한다.
abstract final class AppColors {
  static const primary = Color(0xFF246BFD);
  static const primarySoft = Color(0xFFEDF3FF);
  static const primarySoftStrong = Color(0xFFDCE8FF);

  static const textPrimary = Color(0xFF132238);
  static const textSecondary = Color(0xFF5F6E86);
  static const textHint = Color(0xFF98A3B5);

  /// 개수·입력칸 안내·하단 탭 이름처럼 읽어야 하는 보조 글자 (흰 바탕 약 4.7:1). `textHint`는 장식용.
  static const textTertiary = Color(0xFF6B7890);

  static const ink = Color(0xFF14223A);

  /// 밝기 3단계로 층을 나눈다(그림자 없음): 배경 `bg` → 섹션·카드 `surface`(+ `border` 1px) → 그 안의 카드 `surfaceRaised`.
  static const bg = Color(0xFFEEF1F5);
  static const surface = Color(0xFFF9FAFC);
  static const surfaceRaised = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFEEF2F8);

  static const border = Color(0xFFE4EAF3);

  /// 버튼 외곽선처럼 `border`보다 진해야 하는 테두리 (`프로필 편집` 등)
  static const borderStrong = Color(0xFFCFD7E3);

  /// 선택된 칩의 테두리 (`primarySoft` 배경 위의 연한 파랑)
  static const primaryBorder = Color(0xFF9FBDFD);

  /// 떠 있는 카드·버튼의 그림자 (`ink` 20%)
  static const shadow = Color(0x3314223A);

  /// 지도 위 알약 · 카드 · 핀 · 하단 탭처럼 떠 있는 작은 것의 그림자 (`ink` 16%).
  /// 예전에 화면마다 12~18%로 적던 값을 하나로 합쳤다
  static const shadowFloat = Color(0x2914223A);

  /// 진한 바탕 위에 떠 있는 버튼 · 지도 핀 아이콘의 그림자 (`ink` 25%)
  static const shadowStrong = Color(0x4014223A);

  /// 사진 위 글자를 읽히게 하는 아래쪽 어둠 (`ink` 70% → 투명)
  static const photoScrim = Color(0xB314223A);
  static const photoScrimClear = Color(0x0014223A);

  /// 사진 위 작은 아이콘 칸 바탕 (`ink` 45%)
  static const photoBadge = Color(0x7314223A);

  /// 별점 별
  static const rating = Color(0xFFF5A524);

  /// 안 고른 체크 표시(연한 회색, 07 · 사용자 결정으로 이 모양 유지)
  static const checkOff = Color(0xFFC3CBD7);

  /// 체크박스·라디오 미선택 테두리. `border`는 1.21:1이라 선택 컨트롤에는 이 색을 쓴다(약 3:1).
  static const controlBorder = Color(0xFF8B97AB);
  static const divider = Color(0xFFE9EEF5);
  static const progressInactive = Color(0xFFDCE4F0);

  /// 비활성 버튼 바탕은 `progressInactive`, 글자는 이 색 (바탕 위 약 4.7:1). 투명도로 흐리게 하지 않는다.
  static const disabledText = Color(0xFF56637B);

  /// AI 추천 전용. AI가 추천한 것에만 쓴다.
  static const ai = Color(0xFFF39A45);
  static const aiSoft = Color(0xFFFFF1E4);

  /// AI 추천 이유처럼 읽어야 하는 글자에 쓴다. `ai`는 글자 대비가 2.21:1이라 문장에는 쓰지 않는다.
  static const aiText = Color(0xFFA85400);

  static const danger = Color(0xFFF0645A);
  static const dangerSoft = Color(0xFFFDECEB);

  /// 차단·삭제처럼 위험한 동작의 글자. `danger`는 흰 바탕 글자 대비가 약 3:1이라 문장에는 이 값을 쓴다(약 5:1).
  static const dangerText = Color(0xFFC8463C);
  static const success = Color(0xFF16A07D);

  /// 카테고리 칸(색 12% 바탕) 위 아이콘. `danger` · `success`는 그 바탕과 3:1이 안 돼서
  /// 아이콘만 조금 진하게 쓴다(음식점 3.69:1, 전시 · 문화 3.91:1, UI 리뷰 18)
  static const categoryFoodInk = Color(0xFFD14B41);
  static const categoryCultureInk = Color(0xFF128467);
  static const successSoft = Color(0xFFE6F6F1);

  /// 숙박 카테고리 아이콘 색. 주황(`ai`)은 AI 추천 전용이라 카테고리에는 쓰지 않는다 (07 D17).
  static const stay = Color(0xFFD04C97);

  /// 추출 계열 보조(보라)
  static const extract = Color(0xFF8A63E6);
  static const extractSoft = Color(0xFFF1ECFD);

  static const kakao = Color(0xFFFEE500);
  static const kakaoSoft = Color(0xFFFFF3D6);

  static const scrim = Color(0x8014223A);
  static const placeholder = Color(0xFFE3E9F2);
}
