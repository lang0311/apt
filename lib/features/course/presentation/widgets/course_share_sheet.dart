import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/repositories.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/overlays.dart';
import '../../../../core/widgets/surfaces.dart';
import '../../../party/domain/party_models.dart';
import '../../../party/presentation/widgets/invite_modal.dart';
import '../../domain/course_models.dart';

/// 파티 코스를 파티원에게 알리는 하단 시트. 저장 직후 한 번 뜨고([afterSave], `나중에` 있음),
/// 코스 상세의 파티원 시트에서 다시 열 수 있다.
/// 추가 가능(NEEDS BACKEND): 앱 푸시로 바로 알리기 — 지금은 링크를 직접 보낸다.
Future<void> showCourseShareSheet(
  BuildContext context, {
  required Course course,
  required List<PartyMember>? members,
  bool afterSave = false,
}) {
  final others = members?.otherNames ?? '';
  return showAppBottomSheet<void>(
    context,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xxs, AppSpacing.screenH, AppSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(others.isEmpty ? '파티원에게 코스를 알릴까요?' : '$others에게 알릴까요?', style: AppTypography.cardTitle),
          const SizedBox(height: 2),
          Text('링크를 받으면 코스를 보고 자기 장소를 넣을 수 있어요.', style: AppTypography.meta),
          const SizedBox(height: AppSpacing.md),
          _ShareBody(course: course),
          if (afterSave)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary, minimumSize: const Size(44, 48)),
              child: const Text('나중에'),
            ),
        ],
      ),
    ),
  );
}

class _ShareBody extends ConsumerWidget {
  const _ShareBody({required this.course});
  final Course course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> copy() async {
      try {
        final url = await ref.read(courseRepositoryProvider).courseLink(course.id);
        final date = course.date == null ? '' : ' · ${formatMonthDayWeekday(course.date!)}';
        await Clipboard.setData(ClipboardData(text: '${course.title}$date\n$url'));
        if (context.mounted) showAppSnackBar(context, '코스 링크를 복사했어요.');
      } catch (e) {
        if (context.mounted) showAppSnackBar(context, failureMessage(e));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShareOption(
          background: AppColors.kakaoSoft,
          leading: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.kakao, shape: BoxShape.circle),
            child: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF191919), size: 20),
          ),
          title: '카카오톡으로 보내기',
          description: '단톡방에 코스 보내기',
          // NEEDS: 카카오 SDK(카카오톡 공유) 키 발급
          onTap: () => showAppSnackBar(context, '카카오톡 공유는 준비 중이에요. 링크 복사를 이용해주세요.'),
        ),
        const SizedBox(height: AppSpacing.sm),
        ShareOption(
          background: AppColors.bg,
          leading: const IconCircle(icon: Icons.link_rounded),
          title: '코스 링크 복사',
          description: '링크를 열면 코스 상세로 가요',
          onTap: copy,
        ),
      ],
    );
  }
}
