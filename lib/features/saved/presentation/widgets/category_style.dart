import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// 카테고리 키 → 앱의 아이콘/색 매핑. 목록·개수는 서버 데이터이고,
/// 모르는 카테고리는 기본 아이콘으로 표시한다 (docs/05 #13).
class CategoryStyle {
  const CategoryStyle(this.icon, this.color);
  final IconData icon;
  final Color color;

  static const _map = <String, CategoryStyle>{
    'restaurant': CategoryStyle(Icons.restaurant_rounded, Color(0xFFF0645A)),
    'cafe': CategoryStyle(Icons.local_cafe_rounded, AppColors.primary),
    'tour': CategoryStyle(Icons.landscape_rounded, Color(0xFF8A63E6)),
    'culture': CategoryStyle(Icons.museum_rounded, AppColors.success),
    'stay': CategoryStyle(Icons.hotel_rounded, AppColors.ai),
  };

  static const fallback = CategoryStyle(Icons.place_rounded, AppColors.textSecondary);

  static CategoryStyle of(String? key) => _map[key] ?? _fromKakao(key) ?? fallback;

  /// 팀 서버(카카오 지도)는 'cafe' 같은 키 대신 '음식점 > 카페' 같은 업종 이름을 준다.
  /// 아이콘·색만 고르는 것이고, 카테고리 목록·개수는 그대로 서버 값을 쓴다.
  static CategoryStyle? _fromKakao(String? name) {
    if (name == null) return null;
    if (name.contains('카페')) return _map['cafe'];
    if (name.contains('음식점')) return _map['restaurant'];
    if (name.contains('숙박')) return _map['stay'];
    if (name.contains('문화')) return _map['culture'];
    if (name.contains('여행') || name.contains('관광')) return _map['tour'];
    return null;
  }
}
