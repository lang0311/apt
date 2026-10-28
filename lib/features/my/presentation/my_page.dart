import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/headers.dart';
import '../../../core/widgets/overlays.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/surfaces.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/my_models.dart';
import 'my_providers.dart';

/// #33 마이. 저장됨 · 코스와 같은 SectionCard 묶음 (07 D27).
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
          onRefresh: () async {
            ref.invalidate(myProfileProvider);
            await ref.read(myProfileProvider.future).then((_) {}, onError: (_) {});
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.sm),
                    SectionCard(
                      title: '설정',
                      child: DividedRows(
                        indent: AppSpacing.md,
                        children: [
                          _MenuRow(icon: Icons.notifications_none_rounded, label: '알림', onTap: () => _todo(context, '알림')),
                          _MenuRow(icon: Icons.shield_outlined, label: '개인정보 설정', onTap: () => _todo(context, '개인정보 설정')),
                          _MenuRow(icon: Icons.help_outline_rounded, label: '도움말 및 문의', onTap: () => _todo(context, '도움말 및 문의')),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // 로그아웃은 위험 동작이라 따로 떼어 두고, 누르면 확인 창
                    _LogoutCard(onTap: () => _signOut(context, ref)),
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

class _Profile extends StatelessWidget {
  const _Profile({required this.profile, required this.onEdit});
  final MyProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.md),
          child: Row(
            children: [
              _Avatar(name: profile.nickname, imageUrl: profile.profileImageUrl),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.nickname, style: AppTypography.section.copyWith(fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (profile.handle != null) Text(profile.handle!, style: AppTypography.meta),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: onEdit,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: Color(0xFFCFD7E3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xs)),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.padded,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                ),
                child: Text('프로필 편집', style: AppTypography.meta.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 통계 타일 대신 행 (홈과 같은 이유, 07 D20). 숫자는 서버 aggregate
              SectionCard(
                title: '내 기록',
                child: DividedRows(
                  indent: AppSpacing.md,
                  children: [
                    _MenuRow(label: '저장한 장소', count: profile.savedPlaceCount, onTap: () => context.go(AppRoutes.saved)),
                    _MenuRow(label: '만든 코스', count: profile.createdCourseCount, onTap: () => context.go(AppRoutes.courses)),
                    _MenuRow(label: '함께하는 코스', count: profile.joinedCourseCount, onTap: () => context.go(AppRoutes.coursesParty)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SectionCard(
                title: '취향',
                trailing: AppTextLink(label: '수정', onPressed: () => context.push(AppRoutes.preferences)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xs),
                      child: profile.preferenceLabels.isEmpty
                          ? Text('아직 고른 취향이 없어요.', style: AppTypography.meta)
                          : Text(profile.preferenceLabels.join(' · '), style: AppTypography.bodyStrong),
                    ),
                    const Divider(height: 1, thickness: 1, indent: AppSpacing.md, endIndent: AppSpacing.md, color: AppColors.divider),
                    // 개수는 목록을 받아 세지 않는다 (서버 aggregate 없음)
                    _MenuRow(label: '추천하지 않는 장소', onTap: () => context.push(AppRoutes.blockedPlaces)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 사진이 없으면 이름 첫 글자 원
class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.imageUrl});
  final String name;
  final String? imageUrl;

  static const _size = 52.0;

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

/// SectionCard 안의 메뉴 행: (아이콘 칸) · 이름 · (숫자) · ›
class _MenuRow extends StatelessWidget {
  const _MenuRow({this.icon, required this.label, this.count, required this.onTap});
  final IconData? icon;
  final String label;
  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: count == null ? label : '$label $count',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.sm, AppSpacing.xs),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(9)),
                    child: Icon(icon, size: 18, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(child: Text(label, style: AppTypography.bodyStrong)),
                if (count != null) ...[
                  Text('$count', style: AppTypography.bodyStrong.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 2),
                ],
                const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoutCard extends StatelessWidget {
  const _LogoutCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardAll, side: const BorderSide(color: AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(9)),
                  child: const Icon(Icons.logout_rounded, size: 18, color: AppColors.dangerText),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text('로그아웃', style: AppTypography.bodyStrong.copyWith(color: AppColors.dangerText)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
