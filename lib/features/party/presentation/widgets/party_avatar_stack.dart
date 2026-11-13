import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/party_models.dart';

/// 파티원 아바타 (이니셜 원). 프로필 이미지가 생기면 이미지로 교체한다.
class PartyAvatarStack extends StatelessWidget {
  const PartyAvatarStack({super.key, required this.members, required this.size, required this.max, this.colorOffset = 0, this.overlap = false});
  final List<PartyMember> members;
  final double size;
  final int max;

  /// 한 사람씩 따로 그릴 때(목록 행) 순서에 맞는 색을 쓰도록 시작 색을 민다
  final int colorOffset;

  /// 얼굴을 겹쳐 그린다(한 줄 요약용). 겹친 경계는 바탕색 테두리로 나눈다.
  final bool overlap;

  static const _palette = [
    (AppColors.primarySoftStrong, AppColors.primary),
    (Color(0xFFFDE4DD), Color(0xFFD0573C)),
    (Color(0xFFE2F3EA), AppColors.success),
    (AppColors.extractSoft, AppColors.extract),
  ];

  /// 흰 바탕에 이름만 글자로 쓸 때의 색. 얼굴 색과 같은 짝이되 작은 글씨도 읽히게(대비 4.5 이상) 진하게 한다.
  /// [index]는 얼굴을 그릴 때와 같은 순서(서버 파티원 순서)
  static Color nameColor(int index) => const [
        AppColors.primary,
        Color(0xFFB5432B),
        Color(0xFF0C7259),
        Color(0xFF6B45C9),
      ][index % _palette.length];

  Widget _face(int index, PartyMember member) {
    final (background, foreground) = _palette[(index + colorOffset) % _palette.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: overlap ? Border.all(color: AppColors.surface, width: 1.5) : null,
      ),
      child: Text(
        member.initial,
        style: AppTypography.label.copyWith(
          color: foreground,
          fontSize: size < 30 ? size * 0.45 : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = members.take(max).toList();
    final step = size * 0.7;
    return Semantics(
      label: '파티원 ${members.length}명',
      child: overlap
          ? SizedBox(
              width: shown.isEmpty ? 0 : size + (shown.length - 1) * step,
              height: size,
              child: Stack(
                children: [
                  for (var i = 0; i < shown.length; i++) Positioned(left: i * step, child: _face(i, shown[i])),
                ],
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < shown.length; i++)
                  Padding(
                    padding: EdgeInsets.only(right: i == shown.length - 1 ? 0 : 6),
                    child: _face(i, shown[i]),
                  ),
              ],
            ),
    );
  }
}
