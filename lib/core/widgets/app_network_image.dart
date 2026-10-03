import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// 네트워크 이미지 + 플레이스홀더 + 모서리.
/// 이미지 캐시 패키지(cached_network_image 등)를 도입하면 이 위젯 내부만 바꾼다.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.radius = 14,
    this.placeholderIcon = Icons.image_outlined,
  });

  final String? url;
  final double? width;
  final double? height;
  final double radius;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      color: AppColors.placeholder,
      alignment: Alignment.center,
      child: Icon(placeholderIcon, color: AppColors.textHint, size: 22),
    );
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url == null || url!.isEmpty
          ? placeholder
          : Image.network(
              url!,
              width: width,
              height: height,
              fit: BoxFit.cover,
              // 썸네일 크기로 디코딩해 메모리 절약 (원본 무조건 사용 금지)
              cacheWidth: width == null || !width!.isFinite ? null : (width! * dpr).round(),
              errorBuilder: (_, _, _) => placeholder,
              frameBuilder: (_, child, frame, wasSync) =>
                  wasSync || frame != null ? child : placeholder,
            ),
    );
  }
}
