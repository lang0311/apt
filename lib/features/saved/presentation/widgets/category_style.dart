import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// 카테고리 키 → 앱의 아이콘/색 매핑. 목록·개수는 서버 데이터이고,
/// 모르는 카테고리는 기본 아이콘으로 표시한다 (docs/05 #13).
class CategoryStyle {
  const CategoryStyle(this.icon, this.color, [this._ink]);
  final IconData icon;

  /// 칸 바탕(12%) · 지도 핀 색
  final Color color;
  final Color? _ink;

  /// 카테고리 칸 위 아이콘 색. 바탕과 3:1이 안 되는 색만 따로 진하게 둔다
  Color get ink => _ink ?? color;

  static const _map = <String, CategoryStyle>{
    'restaurant': CategoryStyle(Icons.restaurant_rounded, AppColors.danger, AppColors.categoryFoodInk),
    'cafe': CategoryStyle(Icons.local_cafe_rounded, AppColors.primary),
    'tour': CategoryStyle(Icons.landscape_rounded, AppColors.extract),
    'culture': CategoryStyle(Icons.museum_rounded, AppColors.success, AppColors.categoryCultureInk),
    'stay': CategoryStyle(Icons.hotel_rounded, AppColors.stay),
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
