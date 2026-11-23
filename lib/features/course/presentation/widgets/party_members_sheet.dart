import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../party/domain/party_models.dart';
import '../../../party/presentation/widgets/party_avatar_stack.dart';

/// 코스 상세의 파티원 띠를 누르면 뜨는 시트 내용 — "함께하는 사람 n명".
/// 나를 맨 위에, 초대하기 · 코스 알리기는 사람 목록과 나눠 아래 버튼 두 개로.
/// 초대 링크는 파티장만 만들 수 있어서(서버 403) 파티원에게는 초대하기를 보이지 않는다 (07 D43).
/// 8명이 다 모이면 파티장에게도 초대하기 대신 안내 한 줄 (서버는 9번째 참여를 409로 막는다).
class PartyMembersSheet extends StatelessWidget {
  const PartyMembersSheet({super.key, required this.party, required this.onInvite, required this.onShare});

  final Party party;
  final VoidCallback onInvite;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final members = party.members;
    final ordered = [...members.where((m) => m.isMe), ...members.where((m) => !m.isMe)];
    final canInvite = party.isOwner && !party.isFull;
    final canShare = members.any((m) => !m.isMe);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xxs, AppSpacing.screenH, AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('함께하는 사람 ${members.length}명', style: AppTypography.cardTitle),
          const SizedBox(height: AppSpacing.xs),
          for (final m in ordered)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  // 얼굴 색은 서버 순서 그대로 (상세의 얼굴 묶음과 같은 색)
                  PartyAvatarStack(members: [m], size: 36, max: 1, colorOffset: members.indexOf(m)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(m.nickname, style: AppTypography.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            if (m.isMe) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(AppRadius.tiny)),
                                child: Text(party.isOwner ? '나, 파티장' : '나', style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ],
                        ),
                        // 16번: 저장 수 (서버가 줄 때만). 0곳이면 그 사람 취향은 추천에 들어가지 않는다
                        if (m.savedPlaceCount case final count?)
                          Text(
                            count == 0 ? '저장한 곳이 없어서 추천에 안 들어가요' : '저장 $count곳',
                            style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (party.isOwner && party.isFull) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 11),
              decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(AppRadius.medium)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(LucideIcons.users, size: 16, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text('8명이 다 모여서 더 초대할 수 없어요.', style: AppTypography.meta.copyWith(color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ),
          ],
          if (canInvite || canShare) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                if (canInvite)
                  Expanded(
                    child: AppButton(
                      label: '초대하기',
                      variant: canShare ? AppButtonVariant.white : AppButtonVariant.primary,
                      height: 48,
                      onPressed: onInvite,
                    ),
                  ),
                if (canInvite && canShare) const SizedBox(width: AppSpacing.xs),
                if (canShare)
                  Expanded(
                    child: AppButton(label: '코스 알리기', height: 48, onPressed: onShare),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
