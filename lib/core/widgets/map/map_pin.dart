import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:apt/core/widgets/spark_icon.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/theme/app_spacing.dart';

enum MapPinKind {
  /// 번호 원 (코스 순서)
  numbered,

  /// 고른 장소 (파란 원 + 체크). 고른 순서는 추천에 쓰이지 않아 번호를 붙이지 않는다
  picked,

  /// AI 추천 (주황 원. 번호가 있으면 번호 + 작은 ✦, 없으면 ✦)
  ai,

  /// 저장 장소 핀 (업종 색 동그라미 + 흰 테두리 + 아이콘, v2). 고르면 커지고 파란 빛 테두리
  place,

  /// 찾은 장소 (흰 원 + 업종 색 테두리·아이콘). 저장하면 [place]로 바뀐다.
  result,

  /// 장소 상세 위치 지도의 물방울 핀 (업종 색 + 아이콘, v2 #20)
  drop,
}

class MapPin extends StatelessWidget {
  const MapPin({super.key, required this.kind, this.number, this.label, this.icon, this.color, this.selected = false});

  final MapPinKind kind;
  final int? number;
  final String? label;
  final IconData? icon;
  final Color? color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final pin = switch (kind) {
      // v2: 내가 고른 곳 번호 원은 잉크 (일정 번호와 같은 색, 07 D64)
      MapPinKind.numbered => _circle(
        color ?? AppColors.ink,
        Text(
          '${number ?? ''}',
          style: AppTypography.bodyStrong.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      // v2: 고른 곳도 저장 장소 핀과 같은 크기의 파란 동그라미 + 체크
      MapPinKind.picked => _placeDot(fill: color ?? AppColors.primary, glyph: LucideIcons.check),
      MapPinKind.ai => number == null ? _circle(AppColors.ai, const SparkIcon(color: Colors.white, size: 18)) : _aiNumbered(),
      MapPinKind.place => _placeDot(),
      MapPinKind.result => _result(),
      MapPinKind.drop => _teardrop(),
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
              borderRadius: BorderRadius.circular(AppRadius.small),
              boxShadow: const [BoxShadow(color: AppColors.shadowFloat, blurRadius: 6)],
            ),
            child: Text(
              label!,
              style: AppTypography.caption.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
        // 저장 장소 핀은 고른 모양을 따로 그린다(크기 · 빛 테두리)
        if (kind == MapPinKind.place || kind == MapPinKind.picked)
          pin
        else
          AnimatedScale(scale: selected ? 1.15 : 1, duration: const Duration(milliseconds: 150), child: pin),
      ],
    );
  }

  Widget _circle(Color bg, Widget child) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: child,
    );
  }

  /// 주황 번호 원 오른쪽 위에 작은 ✦. 바깥 크기를 넓혀 가운데(지도 기준점)는 번호 원과 같게 둔다
  Widget _aiNumbered() {
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _circle(
            AppColors.ai,
            Text(
              '$number',
              style: AppTypography.bodyStrong.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          // v2: 오른쪽 위 작은 ✦ 글리프만
          const Positioned(right: 0, top: 0, child: SparkIcon(size: 14, color: AppColors.aiText)),
        ],
      ),
    );
  }

  Widget _result() {
    final c = color ?? AppColors.textSecondary;
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: c, width: 2.5),
        boxShadow: const [BoxShadow(color: AppColors.shadowFloat, blurRadius: 5, offset: Offset(0, 1))],
      ),
      child: Icon(icon ?? LucideIcons.mapPin, size: 17, color: c),
    );
  }

  /// v2 시안: 업종 색 동그라미(흰 테두리 · 흰 아이콘). 고르면 38로 커지고 바깥에 파란 빛 테두리
  Widget _placeDot({Color? fill, IconData? glyph}) {
    final c = fill ?? color ?? AppColors.textSecondary;
    final d = selected ? 38.0 : 28.0;
    final dot = Container(
      width: d,
      height: d,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: selected ? 3 : 2.5),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 5, offset: Offset(0, 1))],
      ),
      child: Icon(glyph ?? icon ?? LucideIcons.mapPin, size: selected ? 19 : 15, color: Colors.white),
    );
    if (!selected) return dot;
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.28), shape: BoxShape.circle),
      child: dot,
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
          Icon(
            Icons.location_on,
            size: 42,
            color: c,
            shadows: const [Shadow(color: AppColors.shadowStrong, blurRadius: 4)],
          ),
          Positioned(top: 8, child: Icon(icon ?? LucideIcons.mapPin, size: 15, color: Colors.white)),
        ],
      ),
    );
  }
}
