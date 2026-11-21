import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/repositories.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/headers.dart';
import '../../../../core/widgets/overlays.dart';
import '../../../../core/widgets/states.dart';
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
    // v2 "32-2": 큰 제목 · 설명 → 화면 끝까지 행(사진 48 · 이름 · 업종 · 뺀 날짜 · 회색 '해제')
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PlainHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(header: true, child: Text('추천하지 않는 장소', style: AppTypography.display)),
                  const SizedBox(height: 6),
                  Text('여기 있는 곳은 코스를 만들거나 다시 추천할 때 나오지 않아요.', style: AppTypography.bodyMuted),
                ],
              ),
            ),
            Expanded(
              child: AsyncValueView<List<BlockedPlace>>(
                value: list,
                onRetry: () => ref.invalidate(blockedPlacesProvider),
                data: (items) => items.isEmpty
                    ? Padding(
                        padding: AppSpacing.screenPadding,
                        child: Text('추천하지 않는 장소가 없어요', style: AppTypography.meta),
                      )
                    : ListView(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                        children: [
                          for (final b in items)
                            Padding(
                              key: ValueKey(b.place.id),
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: 10),
                              child: Row(
                                children: [
                                  AppNetworkImage(url: b.place.imageUrl, width: 48, height: 48, radius: AppRadius.small),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(b.place.name, style: AppTypography.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                                        Text(
                                          [
                                            b.place.categoryLabel,
                                            if (b.blockedAt case final at?) '${at.month}월 ${at.day}일에 뺐어요',
                                          ].join(' · '),
                                          style: AppTypography.meta,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  AppButton(
                                    label: '해제',
                                    variant: AppButtonVariant.secondary,
                                    expand: false,
                                    height: AppSpacing.smallButtonHeight,
                                    onPressed: () => _unblock(context, ref, b),
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
