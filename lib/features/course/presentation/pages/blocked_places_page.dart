import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/repositories.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/headers.dart';
import '../../../../core/widgets/overlays.dart';
import '../../../../core/widgets/states.dart';
import '../../../../core/widgets/surfaces.dart';
import '../../domain/course_models.dart';
import '../course_providers.dart';

/// 마이 → 추천하지 않는 장소. "앞으로 추천하지 않기"로 차단한 장소만 모인다(이번만 뺀 장소는 없음).
/// "해제"하면 다음 추천부터 다시 나올 수 있다.
class BlockedPlacesPage extends ConsumerWidget {
  const BlockedPlacesPage({super.key});

  Future<void> _unblock(BuildContext context, WidgetRef ref, BlockedPlace b) async {
    try {
      await ref.read(courseRepositoryProvider).unblockPlace(b.place.id);
      ref.invalidate(blockedPlacesProvider);
      if (context.mounted) showAppSnackBar(context, '다음 추천부터 다시 나올 수 있어요');
    } catch (e) {
      if (context.mounted) showAppSnackBar(context, failureMessage(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(blockedPlacesProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PlainHeader(title: '추천하지 않는 장소'),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.sm),
              child: Text('여기 있는 장소는 코스를 만들거나 다시 추천할 때 나오지 않아요.', style: AppTypography.meta),
            ),
            Expanded(
              child: AsyncValueView<List<BlockedPlace>>(
                value: list,
                onRetry: () => ref.invalidate(blockedPlacesProvider),
                data: (items) => ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.xl),
                  children: [
                    SectionCard(
                      title: '${items.length}곳',
                      child: items.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(horizontal: SectionCard.innerPadding),
                              child: Text('추천하지 않는 장소가 없어요', style: AppTypography.meta),
                            )
                          : DividedRows(
                              indent: SectionCard.innerPadding + 44 + AppSpacing.sm,
                              children: [
                                for (final b in items)
                                  Padding(
                                    key: ValueKey(b.place.id),
                                    padding: const EdgeInsets.only(left: SectionCard.innerPadding, right: AppSpacing.xxs),
                                    child: Row(
                                      children: [
                                        AppNetworkImage(url: b.place.imageUrl, width: 44, height: 44, radius: 12),
                                        const SizedBox(width: AppSpacing.sm),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(b.place.name, style: AppTypography.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                                                Text(
                                                  [b.place.categoryLabel, if (b.blockedAt case final at?) '${at.month}월 ${at.day}일'].join(' · '),
                                                  style: AppTypography.caption,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () => _unblock(context, ref, b),
                                          style: TextButton.styleFrom(foregroundColor: AppColors.primary, minimumSize: const Size(48, 44)),
                                          child: Text('해제', style: AppTypography.label.copyWith(color: AppColors.primary)),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
