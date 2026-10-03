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

  static CategoryStyle of(String? key) => _map[key] ?? fallback;
}
