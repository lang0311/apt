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
import '../../../../core/widgets/segmented_tabs.dart';
import '../../../../core/widgets/states.dart';
import '../../../../core/widgets/surfaces.dart';
import '../../../party/presentation/party_providers.dart';
import '../../../party/presentation/widgets/invite_modal.dart';
import '../../../party/presentation/widgets/party_avatar_stack.dart';
import '../../../preference/presentation/preference_providers.dart';
import '../../domain/course_models.dart';
import '../course_draft_controller.dart';

/// #25 / #26 동행 설정 (2/4, 정보 다음 · 장소 선택 전) — 한 화면의 [혼자 갈게요 | 함께 갈게요] 토글
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
            const StepHeader(title: '동행 설정', step: 2),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.lg, AppSpacing.screenH, AppSpacing.lg),
                children: [
                  Text('이번 코스는 누구와 함께하나요?', style: AppTypography.title),
                  const SizedBox(height: 4),
                  Text('동행에 따라 AI가 참고할 취향이 달라져요.', style: AppTypography.body),
                  const SizedBox(height: AppSpacing.lg),
                  SegmentedTabs(
                    labels: const ['혼자 갈게요', '함께 갈게요'],
                    selectedIndex: isParty ? 1 : 0,
                    style: SegmentedStyle.pills,
                    onChanged: (i) => _setCompanion(i == 1 ? Companion.party : Companion.solo),
                  ),
                  const SizedBox(height: AppSpacing.lg),
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
                label: '다음: 저장한 장소 선택',
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

class _PartyCard extends ConsumerWidget {
  const _PartyCard({required this.partyId});
  final String partyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final party = ref.watch(partyProvider(partyId));
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('함께할 파티원', style: AppTypography.section),
          const SizedBox(height: 4),
          Text('참여자의 저장 장소와 취향을 추천에 반영해요.', style: AppTypography.meta),
          const SizedBox(height: AppSpacing.md),
          AsyncValueView(
            value: party,
            compactError: true,
            onRetry: () => ref.invalidate(partyProvider(partyId)),
            loading: const SkeletonBox(height: 48),
            data: (p) => Row(
              children: [
                PartyAvatarStack(members: p.members),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('현재 ${p.members.length}명', style: AppTypography.bodyStrong),
                      if (p.preferenceSummary.isNotEmpty)
                        Text('${p.preferenceSummary.join(' · ')} 취향', style: AppTypography.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            color: AppColors.primarySoft,
            radius: AppRadius.input,
            onTap: () => showInviteModal(context, partyId: partyId),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                const Icon(Icons.add_rounded, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text('파티원 추가하기', style: AppTypography.bodyStrong.copyWith(color: AppColors.primary))),
                const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SoloCard extends ConsumerWidget {
  const _SoloCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = ref.watch(myPreferenceLabelsProvider);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconCircle(icon: Icons.person_outline_rounded, size: 48),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('나의 취향으로 추천', style: AppTypography.section),
                    const SizedBox(height: 2),
                    switch (labels) {
                      AsyncData(:final value) when value.isNotEmpty =>
                        Text(value.take(4).join(' · '), style: AppTypography.meta),
                      AsyncData() => AppTextLink(
                          label: '취향 설정하기',
                          trailingChevron: true,
                          onPressed: () => context.push(AppRoutes.preferences),
                        ),
                      AsyncError() => Text('취향을 불러오지 못했어요.', style: AppTypography.meta),
                      _ => const SkeletonBox(width: 140, height: 12),
                    },
                  ],
                ),
              ),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: AppSpacing.md), child: Divider()),
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.ai, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('AI가 빈 시간과 부족한 장소를 채워드려요.', style: AppTypography.body)),
            ],
          ),
        ],
      ),
    );
  }
}
