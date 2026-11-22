import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../place/domain/place.dart';
import 'category_style.dart';

/// 장소 사진. 사진이 없으면 카테고리 색 칸 + 아이콘으로 같은 크기를 유지한다.
class PlaceImage extends StatelessWidget {
  const PlaceImage({
    super.key,
    required this.place,
    required this.width,
    required this.height,
    this.radius = AppRadius.thumb,
    this.iconSize = 22,
    this.iconAlignment = Alignment.center,
  });

  final Place place;
  final double width;
  final double height;
  final double radius;
  final double iconSize;
  final Alignment iconAlignment;

  @override
  Widget build(BuildContext context) {
    if (place.imageUrl != null && place.imageUrl!.isNotEmpty) {
      return AppNetworkImage(url: place.imageUrl, width: width, height: height, radius: radius);
    }
    // v2: 사진이 없으면 업종 색 칸
    return CategoryColorTile(
      style: CategoryStyle.of(place.categoryKey),
      width: width,
      height: height,
      radius: radius,
      iconSize: iconSize,
      iconAlignment: iconAlignment,
    );
  }
}
