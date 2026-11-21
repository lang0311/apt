import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/config/feature_flags.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/headers.dart';
import '../../../core/widgets/overlays.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/surfaces.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../preference/presentation/preference_providers.dart';
import '../../saved/presentation/saved_providers.dart';
import '../domain/my_models.dart';
import 'my_providers.dart';

/// #33 마이 (v2): 프로필 · 숫자 세 칸(테두리 없음) · 띠 · 내 취향(요약 한 줄 + 보기) · 띠 · 설정 행 · 로그아웃(회색 글자).
/// 톱니 · '내 활동'은 뺐다 (07 D26). 하위 화면(알림 · 개인정보 · 도움말 · 프로필 편집)은 디자인 없음 (docs/07 §3).
class MyPage extends ConsumerWidget {
  const MyPage({super.key});

  void _todo(BuildContext context, String name) => showAppSnackBar(context, '$name은(는) 준비 중이에요.');

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(context, title: '로그아웃할까요?', confirmLabel: '로그아웃', destructive: true);
    if (ok) await ref.read(authControllerProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () {
            ref.invalidate(myProfileProvider);
            ref.invalidate(myPreferencesProvider);
            ref.invalidate(savedSummaryProvider);
            return awaitRefresh(context, [ref.read(myProfileProvider.future), ref.read(myPreferenceLabelsProvider.future)]);
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
            children: [
              const PageTitleHeader(title: '마이'),
              AsyncValueView<MyProfile>(
                value: profile,
                onRetry: () => ref.invalidate(myProfileProvider),
                loading: const SkeletonList(count: 3),
                data: (data) => _Profile(profile: data, onEdit: () => _todo(context, '프로필 편집')),
              ),
              const SizedBox(height: 22),
              const SectionGap(),
              const SizedBox(height: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                child: SectionCard(
                  title: '내 취향',
                  trailing: Consumer(
                    builder: (context, ref, _) {
                      final manual = FeatureFlags.manualTasteEnabled && !(ref.watch(preferenceGroupsProvider).value?.isEmpty ?? false);
                      return AppTextLink(label: manual ? '수정' : '보기', onPressed: () => context.push(AppRoutes.preferences));
                    },
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: SectionCard.innerPadding),
                    child: _PreferenceSummary(),
                  ),
                ),
              ),
              // 개수는 목록을 받아 세지 않는다 (서버 aggregate 없음)
              _MenuRow(label: '추천하지 않는 장소', onTap: () => context.push(AppRoutes.blockedPlaces)),
              const SizedBox(height: AppSpacing.xs),
              const SectionGap(),
              const SizedBox(height: AppSpacing.xs),
              _MenuRow(label: '알림', onTap: () => _todo(context, '알림')),
              _MenuRow(label: '개인정보 설정', onTap: () => _todo(context, '개인정보 설정')),
              _MenuRow(label: '도움말 및 문의', onTap: () => _todo(context, '도움말 및 문의')),
              // 로그아웃은 회색 글자 행, 누르면 확인 창
              _MenuRow(label: '로그아웃', muted: true, onTap: () => _signOut(context, ref)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Profile extends StatelessWidget {
  const _Profile({required this.profile, required this.onEdit});
  final MyProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Avatar(name: profile.nickname, imageUrl: profile.profileImageUrl),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.nickname, style: AppTypography.section, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (profile.handle != null)
                      Text(profile.handle!, style: AppTypography.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              AppButton(
                label: '프로필 편집',
                variant: AppButtonVariant.secondary,
                expand: false,
                height: AppSpacing.smallButtonHeight,
                onPressed: onEdit,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // 숫자 세 칸 (칸을 누르면 그 목록으로). 전부 0이면 숫자 대신 첫 행동을 안내한다
          _Stats(profile: profile),
        ],
      ),
    );
  }
}

/// 저장한 곳 · 내 코스 · 함께하는 코스 숫자 세 칸 (v2: 테두리 없음, 숫자 24).
/// 숫자는 목록과 같은 기준(서버 aggregate 대신 목록 저장소, b5ddc90)
class _Stats extends StatelessWidget {
  const _Stats({required this.profile});
  final MyProfile profile;

  /// 1,000부터는 1.2천처럼 줄인다 (칸 폭이 자릿수와 상관없이 같게)
  static String _short(int n) {
    if (n < 1000) return '$n';
    final k = n / 1000;
    return '${k >= 10 ? k.round() : (k * 10).floor() / 10}천'.replaceAll('.0천', '천');
  }

  @override
  Widget build(BuildContext context) {
    final counts = [profile.savedPlaceCount, profile.createdCourseCount, profile.joinedCourseCount];
    if (counts.every((c) => c == 0)) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(color: AppColors.fill, borderRadius: BorderRadius.circular(AppRadius.large)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('아직 기록이 없어요', style: AppTypography.cardTitle),
            const SizedBox(height: 4),
            Text('장소를 저장하고 코스를 만들면 여기에 숫자로 모여요.', style: AppTypography.meta),
            const SizedBox(height: AppSpacing.sm),
            AppButton(label: '첫 장소 저장하기', height: 48, onPressed: () => context.go(AppRoutes.extract)),
          ],
        ),
      );
    }
    final cells = [
      ('저장한 곳', counts[0], AppRoutes.saved),
      ('내 코스', counts[1], AppRoutes.courses),
      ('함께하는 코스', counts[2], AppRoutes.coursesParty),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, (label, count, route)) in cells.indexed) ...[
          if (i > 0) const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Semantics(
              button: true,
              label: '$label $count',
              excludeSemantics: true,
              child: InkWell(
                onTap: () => context.go(route),
                borderRadius: BorderRadius.circular(AppRadius.small),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _short(count),
                        style: AppTypography.hero.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                      ),
                      Text(label, style: AppTypography.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 고른 취향 이름 (다섯 개까지). 로딩 중엔 빈 줄
class _PreferenceSummary extends ConsumerWidget {
  const _PreferenceSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = ref.watch(myPreferenceLabelsProvider);
    // 직접 고르는 취향이 없는 서버(팀 서버)는 저장한 장소로 추천한다
    if (!FeatureFlags.manualTasteEnabled || (ref.watch(preferenceGroupsProvider).value?.isEmpty ?? false)) {
      // 많이 저장한 업종 셋은 서버 요약(카테고리별 수)에서 — 앱이 목록을 세지 않는다
      final top = [...?ref.watch(savedSummaryProvider).value?.categories.where((c) => c.count > 0)]
        ..sort((a, b) => b.count.compareTo(a.count));
      return Text.rich(
        TextSpan(
          text: '저장한 장소를 보고 내 취향에 맞춰 추천해요.',
          children: [
            if (top.isNotEmpty) ...[
              // 업종 이름이 줄 끝에서 글자 단위로 잘리지 않게 새 줄에서 시작한다
              const TextSpan(text: '\n많이 저장한 곳: '),
              TextSpan(
                text: top.take(3).map((c) => c.label).join(' · '),
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
        style: AppTypography.bodyMuted,
      );
    }
    if (!labels.hasValue) {
      return Text(labels.hasError ? '취향을 불러오지 못했어요' : '', style: AppTypography.meta);
    }
    final shown = labels.value!.take(5);
    if (shown.isEmpty) return Text('아직 고른 취향이 없어요.', style: AppTypography.meta);
    return Text(shown.join(' · '), style: AppTypography.bodyStrong);
  }
}

/// 사진이 없으면 이름 첫 글자 원
class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.imageUrl});
  final String name;
  final String? imageUrl;

  static const _size = 56.0;

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return AppNetworkImage(url: imageUrl, width: _size, height: _size, radius: _size / 2);
    }
    return Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
      child: Text(
        name.isEmpty ? '?' : name.characters.first,
        style: AppTypography.section.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// 메뉴 행 (v2): 이름 · › , 좌우 20. [muted]는 로그아웃처럼 회색 글자에 › 없이
class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.label, required this.onTap, this.muted = false});
  final String label;
  final VoidCallback onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xs, AppSpacing.md, AppSpacing.xs),
            child: Row(
              children: [
                Expanded(child: Text(label, style: AppTypography.body.copyWith(color: muted ? AppColors.textTertiary : null))),
                if (!muted) const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
