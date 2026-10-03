import 'package:flutter/material.dart';

String _two(int v) => v.toString().padLeft(2, '0');

/// 2026. 10. 12
String formatDate(DateTime d) => '${d.year}. ${_two(d.month)}. ${_two(d.day)}';

/// 오전 11:00
String formatTimeOfDay(TimeOfDay t) {
  final period = t.hour < 12 ? '오전' : '오후';
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$period $h:${_two(t.minute)}';
}

/// 11:00 (24시간)
String formatClock(TimeOfDay t) => '${_two(t.hour)}:${_two(t.minute)}';

/// 방금 / N분 전 / N시간 전 / N일 전 / 날짜
String formatRelative(DateTime time, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(time);
  if (diff.inMinutes < 1) return '방금';
  if (diff.inHours < 1) return '${diff.inMinutes}분 전';
  if (diff.inDays < 1) return '${diff.inHours}시간 전';
  if (diff.inDays < 7) return '${diff.inDays}일 전';
  return formatDate(time);
}

/// 5시간 20분
String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h == 0) return '$m분';
  if (m == 0) return '$h시간';
  return '$h시간 $m분';
}

/// 1.4km / 850m
String formatDistance(int meters) =>
    meters >= 1000 ? '${(meters / 1000).toStringAsFixed(1)}km' : '${meters}m';

/// 날짜(시각 제외) 기준 D-day. 오늘=0, 미래=양수, 과거=음수.
int daysUntil(DateTime target, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final a = DateTime(n.year, n.month, n.day);
  final b = DateTime(target.year, target.month, target.day);
  return b.difference(a).inDays;
}

String ddayLabel(DateTime target, {DateTime? now}) {
  final d = daysUntil(target, now: now);
  if (d == 0) return 'D-DAY';
  return d > 0 ? 'D-$d' : 'D+${-d}';
}
