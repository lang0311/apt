import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/repositories.dart';
import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/widgets/bottom_cta.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/headers.dart';
import '../../../../core/widgets/overlays.dart';
import '../../../../core/widgets/selection.dart';
import '../../../../core/widgets/states.dart';
import '../../../../core/widgets/surfaces.dart';
import '../../../party/presentation/party_providers.dart';
import '../../../party/presentation/widgets/invite_modal.dart';
import '../../../party/presentation/widgets/party_avatar_stack.dart';
import '../../../preference/presentation/preference_providers.dart';
import '../../domain/course_models.dart';
import '../course_draft_controller.dart';

/// #25 / #26 동행 설정 (2/4, 정보 다음 · 장소 선택 전) — 혼자 가요 / 함께 가요 라디오
class CompanionPage extends ConsumerStatefulWidget {
  const CompanionPage({super.key});

  @override
  ConsumerState<CompanionPage> createState() => _CompanionPageState();
}

class _CompanionPageState extends ConsumerState<CompanionPage> {
  bool _creatingParty = false;

  CourseDraftController get _draft => ref.read(courseDraftProvider.notifier);

  Future<void> _setCompanion(Companion c) async {
    _draft.update((d) => d.copyWith(companion: c));
    if (c != Companion.party || ref.read(courseDraftProvider).partyId != null) return;
    setState(() => _creatingParty = true);
    try {
      final party = await ref.read(partyRepositoryProvider).createParty();
      _draft.update((d) => d.copyWith(partyId: party.id));
    } catch (e) {
      _draft.update((d) => d.copyWith(companion: Companion.solo));
      if (mounted) showAppSnackBar(context, failureMessage(e));
    } finally {
      if (mounted) setState(() => _creatingParty = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(courseDraftProvider);
    final isParty = draft.companion == Companion.party;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const StepHeader(step: 2),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.lg, AppSpacing.screenH, AppSpacing.lg),
                children: [
                  Text('누구와 함께 가나요?', style: AppTypography.title),
                  const SizedBox(height: AppSpacing.md),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _RadioRow(
                          title: '혼자 가요',
                          description: '내 취향으로 추천해요',
                          selected: !isParty,
                          onTap: () => _setCompanion(Companion.solo),
                        ),
                        const Divider(height: 1, indent: AppSpacing.md, endIndent: AppSpacing.md, color: AppColors.divider),
                        _RadioRow(
                          title: '함께 가요',
                          description: '파티원 취향을 함께 반영해요',
                          selected: isParty,
                          onTap: () => _setCompanion(Companion.party),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (isParty)
                    _creatingParty || draft.partyId == null
                        ? const AppLoading(message: '파티를 만들고 있어요')
                        : _PartyCard(partyId: draft.partyId!)
                  else
                    const _SoloCard(),
                ],
              ),
            ),
            BottomCta(
              child: AppButton(
                label: '다음',
                // 함께 가요를 골라도 초대 수락을 기다리지 않고 넘어간다
                onPressed: !_creatingParty && (!isParty || draft.partyId != null)
                    ? () => context.push(AppRoutes.courseNewPlaces)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadioRow extends StatelessWidget {
  const _RadioRow({required this.title, required this.description, required this.selected, required this.onTap});
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
          child: Row(
            children: [
              RadioDot(selected: selected),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.bodyStrong),
                    Text(description, style: AppTypography.caption),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 파티원: 사람마다 한 행 + 마지막 "초대하기"
class _PartyCard extends ConsumerWidget {
  const _PartyCard({required this.partyId});
  final String partyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final party = ref.watch(partyProvider(partyId));
    return SectionCard(
      title: party.hasValue ? '파티원 ${party.value!.members.length}' : '파티원',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AsyncValueView(
            value: party,
            compactError: true,
            onRetry: () => ref.invalidate(partyProvider(partyId)),
            loading: const Padding(padding: EdgeInsets.symmetric(horizontal: AppSpacing.md), child: SkeletonBox(height: 48)),
            data: (p) => DividedRows(
              indent: SectionCard.innerPadding + 36 + AppSpacing.sm,
              children: [
                for (final (i, m) in p.members.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: SectionCard.innerPadding, vertical: 10),
                    child: Row(
                      children: [
                        PartyAvatarStack(members: [m], size: 36, max: 1, colorOffset: i),
                        const SizedBox(width: AppSpacing.sm),
                        // NEEDS BACKEND: 파티원별 취향 요약 (오면 이름 아래 한 줄)
                        Text(m.isMe ? '나' : m.nickname, style: AppTypography.bodyStrong),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          InkWell(
            onTap: () => showInviteModal(context, partyId: partyId),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: SectionCard.innerPadding, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                    child: const Icon(Icons.add_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text('초대하기', style: AppTypography.bodyStrong.copyWith(color: AppColors.primary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 혼자: 반영할 취향 한 줄 + 취향 수정
class _SoloCard extends ConsumerWidget {
  const _SoloCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = ref.watch(myPreferenceLabelsProvider);
    return SectionCard(
      title: '반영할 취향',
      trailing: TextButton(
        onPressed: () => context.push(AppRoutes.preferences),
        style: TextButton.styleFrom(foregroundColor: AppColors.primary, minimumSize: const Size(44, 44)),
        child: Text('취향 수정', style: AppTypography.meta.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SectionCard.innerPadding),
        child: switch (labels) {
          AsyncData(:final value) when value.isNotEmpty => Text(value.take(5).join(' · '), style: AppTypography.bodyStrong),
          AsyncData() => Text('아직 고른 취향이 없어요', style: AppTypography.meta),
          AsyncError() => Text('취향을 불러오지 못했어요', style: AppTypography.meta),
          _ => const SkeletonBox(width: 160, height: 14),
        },
      ),
    );
  }
}
