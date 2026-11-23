import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/widgets/states.dart';
import '../course_providers.dart';

/// '내일 오전 9시부터 다시 받을 수 있어요' (12번). 서버는 UTC 0시(한국 오전 9시)에 사용량을 초기화한다.
/// 사용량을 못 읽었으면 서버 규칙대로 다음 오전 9시(한국 시간)로 말한다.
String quotaResetLabel(DateTime? resetAt, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final at = (resetAt ?? _nextUtcMidnight(current)).toLocal();
  final today = DateUtils.dateOnly(current);
  final day = DateUtils.dateOnly(at);
  final when = day == today ? '오늘' : (day == today.add(const Duration(days: 1)) ? '내일' : '${at.month}월 ${at.day}일');
  final minute = at.minute == 0 ? '' : ' ${at.minute}분';
  // 자정은 '오전 12시'가 헷갈려 '0시'로 (한국 시간이면 오전 9시라 기기 시간대가 다를 때만 나온다)
  final String clock;
  if (at.hour == 0) {
    clock = '0시';
  } else {
    final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
    clock = '${at.hour < 12 ? '오전' : '오후'} $hour시';
  }
  return '$when $clock$minute부터 다시 받을 수 있어요';
}

DateTime _nextUtcMidnight(DateTime now) {
  final utc = now.toUtc();
  return DateTime.utc(utc.year, utc.month, utc.day + 1);
}

/// 추천을 기다리다 한도에 걸렸을 때 (4/4 자리). 고른 장소는 초안에 그대로 남아 있다
class QuotaExceededView extends ConsumerWidget {
  const QuotaExceededView({super.key, required this.onConfirm});
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resetAt = ref.watch(recommendationQuotaProvider).value?.resetAt;
    return Center(
      child: SingleChildScrollView(
        child: AppEmptyState(
          icon: LucideIcons.clock,
          title: '오늘 받을 수 있는 추천을 다 썼어요',
          description: '${quotaResetLabel(resetAt)}.\n고른 장소는 그대로 남아 있어요.',
          actionLabel: '확인',
          onAction: onConfirm,
        ),
      ),
    );
  }
}
