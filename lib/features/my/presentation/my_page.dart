import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/headers.dart';
import '../../../core/widgets/overlays.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/surfaces.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/my_models.dart';
import 'my_providers.dart';

/// #33 마이 프로필·설정
class MyPage extends ConsumerWidget {
  const MyPage({super.key});

  // 하위 화면(내 활동·알림·개인정보·도움말)은 디자인 없음 (docs/07 §3)
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
          onRefresh: () async {
            ref.invalidate(myProfileProvider);
            await ref.read(myProfileProvider.future).then((_) {}, onError: (_) {});
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
            children: [
              PageTitleHeader(
                title: '마이',
                trailing: AppIconBox(icon: Icons.settings_outlined, size: 44, tooltip: '설정', onPressed: () => _todo(context, '설정')),
              ),
              AsyncValueView<MyProfile>(
                value: profile,
                onRetry: () => ref.invalidate(myProfileProvider),
                loading: const SkeletonList(count: 2),
                data: (p) => _ProfileSection(profile: p, onEdit: () => _todo(context, '프로필 편집')),
              ),
              const SizedBox(height: AppSpacing.sm),
              _MenuItem(icon: Icons.bookmark_border_rounded, label: '내 활동', onTap: () => _todo(context, '내 활동')),
              _MenuItem(icon: Icons.notifications_none_rounded, label: '알림', onTap: () => _todo(context, '알림')),
              _MenuItem(icon: Icons.shield_outlined, label: '개인정보 설정', onTap: () => _todo(context, '개인정보 설정')),
              _MenuItem(icon: Icons.help_outline_rounded, label: '도움말 및 문의', onTap: () => _todo(context, '도움말 및 문의')),
              const SizedBox(height: AppSpacing.md),
              _MenuItem(icon: Icons.logout_rounded, label: '로그아웃', color: AppColors.danger, onTap: () => _signOut(context, ref)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.profile, required this.onEdit});
  final MyProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.card),
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  const IconCircle(icon: Icons.person_outline_rounded, size: 72),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.nickname, style: AppTypography.title),
                        if (profile.handle != null) Text(profile.handle!, style: AppTypography.body),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Row(
              children: [
                _Stat(label: '저장한 장소', value: profile.savedPlaceCount, onTap: () => context.go(AppRoutes.saved)),
                _Stat(label: '만든 코스', value: profile.createdCourseCount, onTap: () => context.go(AppRoutes.courses)),
                _Stat(label: '참여한 코스', value: profile.joinedCourseCount, onTap: () => context.go(AppRoutes.courses)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            onTap: () => context.push(AppRoutes.preferences),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune_rounded, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text('취향 설정', style: AppTypography.cardTitle)),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (profile.preferenceLabels.isEmpty)
                  Text('아직 설정한 취향이 없어요. 취향을 고르면 추천이 더 정확해져요.', style: AppTypography.meta)
                else
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final l in profile.preferenceLabels)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: AppRadius.pillAll),
                          child: Text(l, style: AppTypography.label.copyWith(color: AppColors.textSecondary)),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.onTap});
  final String label;
  final int value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          label: '$label $value',
          child: Column(
            children: [
              Text(label, style: AppTypography.meta),
              const SizedBox(height: 4),
              Text('$value', style: AppTypography.statNumber),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label, required this.onTap, this.color});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg + 4),
      leading: Icon(icon, color: color ?? AppColors.textSecondary),
      title: Text(label, style: AppTypography.bodyStrong.copyWith(fontSize: 15, color: color)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }
}
