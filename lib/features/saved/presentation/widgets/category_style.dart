import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';

/// 카테고리 키 → 앱의 아이콘/색 매핑. 목록·개수는 서버 데이터이고,
/// 모르는 카테고리는 기본 아이콘으로 표시한다 (docs/05 #13).
class CategoryStyle {
  const CategoryStyle(this.icon, this.light, this.color);
  final IconData icon;

  /// 그라데이션 밝은 쪽 (v2 업종 색 칸)
  final Color light;

  /// 업종 색 (진한 쪽). 지도 핀 · 칸 그라데이션 끝 · 아이콘 색
  final Color color;

  /// 연한 바탕 위 아이콘 색
  Color get ink => color;

  /// v2 업종 색 칸 그라데이션 (140°, 밝은 쪽 → 진한 쪽)
  LinearGradient get gradient => LinearGradient(begin: const Alignment(-0.77, -0.64), end: const Alignment(0.77, 0.64), colors: [light, color]);

  static const _map = <String, CategoryStyle>{
    'restaurant': CategoryStyle(LucideIcons.utensils, AppColors.catFoodLight, AppColors.catFood),
    'cafe': CategoryStyle(LucideIcons.coffee, AppColors.catCafeLight, AppColors.catCafe),
    'tour': CategoryStyle(LucideIcons.treePine, AppColors.catNatureLight, AppColors.catNature),
    'culture': CategoryStyle(LucideIcons.image, AppColors.catCultureLight, AppColors.catCulture),
    'shop': CategoryStyle(LucideIcons.shoppingBag, AppColors.catShopLight, AppColors.catShop),
    'bar': CategoryStyle(LucideIcons.martini, AppColors.catStayLight, AppColors.catStay),
    'stay': CategoryStyle(LucideIcons.bedDouble, AppColors.catStayLight, AppColors.catStay),
  };

  static const fallback = CategoryStyle(LucideIcons.mapPin, AppColors.catEtcLight, AppColors.catEtc);

  static CategoryStyle of(String? key) => _map[key] ?? _fromKakao(key) ?? fallback;

  /// 팀 서버(카카오 지도)는 'cafe' 같은 키 대신 '음식점 > 카페' 같은 업종 이름을 준다.
  /// 아이콘·색만 고르는 것이고, 카테고리 목록·개수는 그대로 서버 값을 쓴다.
  static CategoryStyle? _fromKakao(String? name) {
    if (name == null) return null;
    if (name.contains('카페')) return _map['cafe'];
    if (name.contains('술집') || name.contains('호프')) return _map['bar'];
    if (name.contains('음식점')) return _map['restaurant'];
    if (name.contains('숙박')) return _map['stay'];
    if (name.contains('문화')) return _map['culture'];
    if (name.contains('쇼핑') || name.contains('패션') || name.contains('팝업')) return _map['shop'];
    if (name.contains('여행') || name.contains('관광')) return _map['tour'];
    return null;
  }
}

/// 사진이 없을 때의 업종 색 칸 (v2: 업종 그라데이션 + 오른쪽 위 밝은 빛 · 왼쪽 아래 그늘 + 흰 아이콘)
class CategoryColorTile extends StatelessWidget {
  const CategoryColorTile({
    super.key,
    required this.style,
    required this.width,
    required this.height,
    required this.radius,
    this.iconSize,
    this.iconAlignment = Alignment.center,
  });

  final CategoryStyle style;
  final double width;
  final double height;
  final double radius;
  final double? iconSize;
  final Alignment iconAlignment;

  @override
  Widget build(BuildContext context) {
    final side = width < height ? width : height;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(gradient: style.gradient, borderRadius: BorderRadius.circular(radius)),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const RadialGradient(center: Alignment(0.5, -0.6), radius: 0.9, colors: [Color(0x59FFFFFF), Color(0x00FFFFFF)]),
      ),
      alignment: iconAlignment,
      child: Icon(style.icon, size: iconSize ?? side * 0.42, color: const Color(0xEBFFFFFF)),
    );
  }
}
