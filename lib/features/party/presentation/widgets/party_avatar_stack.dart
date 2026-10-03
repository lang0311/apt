import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/party_models.dart';

/// 파티원 아바타 (이니셜 원). 프로필 이미지가 생기면 이미지로 교체한다.
class PartyAvatarStack extends StatelessWidget {
  const PartyAvatarStack({super.key, required this.members, this.size = 48, this.max = 4});
  final List<PartyMember> members;
  final double size;
  final int max;

  static const _palette = [
    (AppColors.primarySoftStrong, AppColors.primary),
    (Color(0xFFFDE4DD), Color(0xFFD0573C)),
    (Color(0xFFE2F3EA), AppColors.success),
    (AppColors.extractSoft, AppColors.extract),
  ];

  @override
  Widget build(BuildContext context) {
    final shown = members.take(max).toList();
    return Semantics(
      label: '파티원 ${members.length}명',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < shown.length; i++)
            Padding(
              padding: EdgeInsets.only(right: i == shown.length - 1 ? 0 : 6),
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: _palette[i % _palette.length].$1, shape: BoxShape.circle),
                child: Text(
                  shown[i].initial,
                  style: AppTypography.label.copyWith(color: _palette[i % _palette.length].$2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
