import 'package:apt/core/utils/formatters.dart';
import 'package:apt/core/utils/instagram_url.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InstagramUrl', () {
    test('공유 텍스트 안의 릴스/게시물 URL을 찾는다', () {
      expect(
        InstagramUrl.extract('이 릴스 봐봐 https://www.instagram.com/reel/DA7mNpQrStU/?igsh=abc 대박'),
        'https://www.instagram.com/reel/DA7mNpQrStU/?igsh=abc',
      );
      expect(InstagramUrl.extract('https://instagram.com/p/C3k9xYz'), 'https://instagram.com/p/C3k9xYz');
    });

    test('인스타그램 게시물이 아니면 null', () {
      expect(InstagramUrl.extract('https://www.instagram.com/seoul_daily/'), isNull);
      expect(InstagramUrl.extract('https://youtube.com/watch?v=1'), isNull);
      expect(InstagramUrl.extract(null), isNull);
    });
  });

  group('formatters', () {
    test('날짜/시간', () {
      expect(formatDate(DateTime(2026, 10, 2)), '2026. 10. 02');
      expect(formatTimeOfDay(const TimeOfDay(hour: 11, minute: 0)), '오전 11:00');
      expect(formatTimeOfDay(const TimeOfDay(hour: 13, minute: 5)), '오후 1:05');
      expect(formatTimeOfDay(const TimeOfDay(hour: 0, minute: 30)), '오전 12:30');
    });

    test('소요 시간/거리', () {
      expect(formatDuration(const Duration(hours: 5, minutes: 20)), '5시간 20분');
      expect(formatDuration(const Duration(minutes: 50)), '50분');
      expect(formatDistance(1400), '1.4km');
      expect(formatDistance(850), '850m');
    });

    test('D-day는 날짜 기준으로 계산한다 (시각 무시)', () {
      final now = DateTime(2026, 10, 4, 23, 59);
      expect(ddayLabel(DateTime(2026, 10, 4, 0, 1), now: now), 'D-DAY');
      expect(ddayLabel(DateTime(2026, 10, 12), now: now), 'D-8');
      expect(ddayLabel(DateTime(2026, 10, 1), now: now), 'D+3');
    });

    test('상대 시간', () {
      final now = DateTime(2026, 10, 4, 12);
      expect(formatRelative(now.subtract(const Duration(days: 2)), now: now), '2일 전');
      expect(formatRelative(now.subtract(const Duration(minutes: 5)), now: now), '5분 전');
    });
  });
}
