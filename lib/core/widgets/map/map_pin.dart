import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';

enum MapPinKind {
  /// 번호 원 (코스 순서, 선택 순서)
  numbered,

  /// AI 추천 (주황 ✦)
  ai,

  /// 저장 장소 핀 (카테고리 색 + 아이콘)
  place,

  /// 묶음 (N곳)
  cluster,
}

class MapPin extends StatelessWidget {
  const MapPin({
    super.key,
    required this.kind,
    this.number,
    this.label,
    this.icon,
    this.color,
    this.selected = false,
  });

  final MapPinKind kind;
  final int? number;
  final String? label;
  final IconData? icon;
  final Color? color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final pin = switch (kind) {
      MapPinKind.numbered => _circle(
          color ?? AppColors.primary,
          Text('${number ?? ''}', style: AppTypography.bodyStrong.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
        ),
      MapPinKind.ai => _circle(AppColors.ai, const Icon(Icons.auto_awesome, color: Colors.white, size: 18)),
      MapPinKind.cluster => _circle(
          color ?? AppColors.primary,
          Text('${number ?? ''}', style: AppTypography.label.copyWith(color: Colors.white)),
          size: 34,
        ),
      MapPinKind.place => _teardrop(),
    };

    if (label == null && !selected) return pin;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Color(0x2214223A), blurRadius: 6)],
            ),
            child: Text(label!, style: AppTypography.caption.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          ),
        AnimatedScale(scale: selected ? 1.15 : 1, duration: const Duration(milliseconds: 150), child: pin),
      ],
    );
  }

  Widget _circle(Color bg, Widget child, {double size = 38}) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x3314223A), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: child,
    );
  }

  Widget _teardrop() {
    final c = color ?? AppColors.danger;
    return SizedBox(
      width: 34,
      height: 42,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Icon(Icons.location_on, size: 42, color: c, shadows: const [Shadow(color: Color(0x4414223A), blurRadius: 4)]),
          Positioned(
            top: 8,
            child: Icon(icon ?? Icons.place, size: 15, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
