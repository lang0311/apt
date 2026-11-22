import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';

/// 장소 상세 이름 아래 행동 칸 (리디자인 v2): 저장 · 카카오맵 · 전화. 서버가 준 값이 있는 칸만 같은 폭으로 나눈다.
/// 저장됨(켜진 상태)은 잉크 바탕 + 흰 글자, 나머지는 채움 바탕.
class PlaceActionTiles extends StatelessWidget {
  const PlaceActionTiles({super.key, required this.saved, required this.onSave, this.onMap, this.onCall});

  final bool saved;
  final VoidCallback onSave;

  /// 카카오맵 링크가 있을 때만
  final VoidCallback? onMap;

  /// 전화번호가 있을 때만
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      _Tile(icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, label: saved ? '저장됨' : '저장하기', dark: saved, onTap: onSave),
      if (onMap != null) _Tile(icon: Icons.map_outlined, label: '카카오맵', onTap: onMap!),
      if (onCall != null) _Tile(icon: Icons.call_outlined, label: '전화', onTap: onCall!),
    ];
    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: tiles[i])],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.onTap, this.dark = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : AppColors.textPrimary;
    return Material(
      color: dark ? AppColors.textPrimary : AppColors.fill,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(height: 3),
              Text(label, style: AppTypography.label.copyWith(color: fg), maxLines: 1),
            ],
          ),
        ),
      ),
    );
  }
}
