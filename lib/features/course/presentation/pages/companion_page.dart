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
import '../../../party/domain/party_models.dart';
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
  /// '새 파티 만들기'를 골랐다. 파티는 '다음'(또는 초대하기)을 누를 때 만든다 — 서버에서 지울 수 없어 빈 파티가 쌓이지 않게.
  bool _newParty = false;
  bool _creatingParty = false;

  CourseDraftController get _draft => ref.read(courseDraftProvider.notifier);

  void _setCompanion(Companion companion) => _draft.update((d) => d.copyWith(companion: companion));

  void _pickParty(String id) {
    setState(() => _newParty = false);
    _draft.update((d) => d.copyWith(partyId: id));
  }

  void _pickNewParty() {
    setState(() => _newParty = true);
    _draft.update((d) => d.copyWith(clearPartyId: true));
  }

  /// 새 파티를 아직 안 만들었으면 만든다. 실패하면 null.
  Future<String?> _ensureParty() async {
    final id = ref.read(courseDraftProvider).partyId;
    if (id != null) return id;
    setState(() => _creatingParty = true);
    try {
      final party = await ref.read(partyRepositoryProvider).createParty();
      _draft.update((d) => d.copyWith(partyId: party.id));
      return party.id;
    } catch (e) {
      if (mounted) showAppSnackBar(context, failureMessage(e));
      return null;
    } finally {
      if (mounted) setState(() => _creatingParty = false);
    }
  }

  Future<void> _invite() async {
    final id = await _ensureParty();
    if (id != null && mounted) await showInviteModal(context, partyId: id);
  }

  Future<void> _next() async {
    final party = ref.read(courseDraftProvider).companion == Companion.party;
    if (party && await _ensureParty() == null) return;
    if (mounted) context.push(AppRoutes.courseNewPlaces);
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(courseDraftProvider);
    final isParty = draft.companion == Companion.party;
    // 함께 가요를 골라도 초대 수락을 기다리지 않고 넘어간다
    final canNext = !_creatingParty && (!isParty || draft.partyId != null || _newParty);

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
                    _PartyPicker(
                      selectedId: draft.partyId,
                      newParty: _newParty,
                      onPick: _pickParty,
                      onPickNew: _pickNewParty,
                      onInvite: _creatingParty ? null : _invite,
                    )
                  else
                    const _SoloCard(),
                ],
              ),
            ),
            BottomCta(
              child: AppButton(
                label: '다음',
                loading: _creatingParty,
                onPressed: canNext ? _next : null,
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
              CheckMark(checked: selected),
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

/// 함께 가요: 내 파티 목록(한 줄씩) + 새 파티 만들기. 파티가 없으면 새 파티 카드만.
class _PartyPicker extends ConsumerWidget {
  const _PartyPicker({
    required this.selectedId,
    required this.newParty,
    required this.onPick,
    required this.onPickNew,
    required this.onInvite,
  });
  final String? selectedId;
  final bool newParty;
  final ValueChanged<String> onPick;
  final VoidCallback onPickNew;
  final VoidCallback? onInvite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parties = ref.watch(myPartiesProvider);
    final newCard = _NewPartyCard(partyId: newParty ? selectedId : null, onInvite: onInvite);
    return AsyncValueView<List<Party>>(
      value: parties,
      compactError: true,
      onRetry: () => ref.invalidate(myPartiesProvider),
      loading: const SkeletonBox(height: 160),
      data: (list) {
        if (list.isEmpty) return newCard;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionCard(
              title: '어느 파티와 갈까요?',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DividedRows(
                    indent: SectionCard.innerPadding,
                    children: [
                      for (final p in list)
                        _PartyRow(
                          selected: !newParty && p.id == selectedId,
                          label: p.members.crewNames,
                          count: '${p.members.length}명',
                          onTap: () => onPick(p.id),
                        ),
                      _PartyRow(selected: newParty, label: '새 파티 만들기', onTap: onPickNew, accent: true),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(SectionCard.innerPadding, AppSpacing.xxs, SectionCard.innerPadding, 0),
                    child: Text('고른 파티원이 저장한 장소와 취향을 추천에 반영해요.', style: AppTypography.caption),
                  ),
                ],
              ),
            ),
            if (newParty) ...[const SizedBox(height: AppSpacing.sm), newCard],
          ],
        );
      },
    );
  }
}

/// 파티 한 줄(높이 48): 라디오 · 파티원 이름(넘치면 말줄임) · 인원
class _PartyRow extends StatelessWidget {
  const _PartyRow({required this.selected, required this.label, required this.onTap, this.count, this.accent = false});
  final bool selected;
  final String label;
  final String? count;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      label: count == null ? label : '$label, $count',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: SectionCard.innerPadding),
            child: Row(
              children: [
                CheckMark(checked: selected),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: accent ? AppTypography.bodyStrong.copyWith(color: AppColors.primary) : AppTypography.bodyStrong,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Text(count!, style: AppTypography.meta),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 새 파티: 파티원(아직 만들기 전이면 나 혼자) + 초대하기
class _NewPartyCard extends ConsumerWidget {
  const _NewPartyCard({required this.partyId, required this.onInvite});
  final String? partyId;
  final VoidCallback? onInvite;

  static const _me = [PartyMember(id: 'me', nickname: '나', isMe: true)];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = partyId == null ? _me : ref.watch(partyProvider(partyId!)).value?.members ?? _me;
    return SectionCard(
      title: '파티원 ${members.length}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DividedRows(
            indent: SectionCard.innerPadding + 36 + AppSpacing.sm,
            children: [
              for (final (i, m) in members.indexed)
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
          InkWell(
            onTap: onInvite,
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
