import 'package:apt/features/place/domain/place_timing.dart';
import 'package:flutter_test/flutter_test.dart';

/// 서버 API 1번: 팝업 · 행사 · 신규 오픈 표시 문구 (2026-11-15 성수 실제 응답 기준)
void main() {
  final today = DateTime(2026, 11, 15);
  final popup = PlaceTiming.fromJson({'kind': 'popup', 'start_date': '2026-11-11', 'end_date': '2026-11-29', 'checked_on': '2026-11-15'});

  group('fromJson', () {
    test('팝업은 시작 · 끝 날짜를 읽는다', () {
      expect(popup!.kind, PlaceTimingKind.popup);
      expect(popup.start, DateTime(2026, 11, 11));
      expect(popup.end, DateTime(2026, 11, 29));
      expect(popup.checkedOn, DateTime(2026, 11, 15));
    });

    test('일반 장소 · 값 없음 · 모르는 종류는 null', () {
      expect(PlaceTiming.fromJson({'kind': 'place', 'start_date': '', 'end_date': ''}), isNull);
      expect(PlaceTiming.fromJson(null), isNull);
      expect(PlaceTiming.fromJson({'kind': 'sale'}), isNull);
    });

    test('팝업인데 끝 날짜가 없거나 깨졌으면 null', () {
      expect(PlaceTiming.fromJson({'kind': 'event', 'start_date': '2026-11-11', 'end_date': ''}), isNull);
      expect(PlaceTiming.fromJson({'kind': 'popup', 'end_date': '11월 29일'}), isNull);
    });

    test('신규 오픈은 날짜가 없어도 읽는다', () {
      final t = PlaceTiming.fromJson({'kind': 'new_opening', 'start_date': '', 'end_date': '', 'checked_on': '2026-11-15'});
      expect(t!.kind, PlaceTimingKind.newOpening);
      expect(t.start, isNull);
    });
  });

  group('일정 줄 태그', () {
    test('코스 날짜에 열려 있으면 끝 날짜까지', () {
      expect(timingBadge(popup, courseDate: DateTime(2026, 11, 22), today: today), const TimingBadge('팝업 · 11/29까지', TimingTone.normal));
    });

    test('코스 날짜가 끝나는 날이면 당일 종료', () {
      expect(timingBadge(popup, courseDate: DateTime(2026, 11, 29), today: today), const TimingBadge('팝업 · 당일 종료', TimingTone.normal));
    });

    test('코스 날짜보다 먼저 끝나면 빨간 끝 날짜', () {
      expect(timingBadge(popup, courseDate: DateTime(2026, 12, 5), today: today), const TimingBadge('팝업 · 11/29 종료', TimingTone.warn));
    });

    test('코스 날짜에 아직 시작 전이면 빨간 시작 날짜', () {
      expect(timingBadge(popup, courseDate: DateTime(2026, 11, 8), today: DateTime(2026, 11, 5)), const TimingBadge('팝업 · 11/11 시작', TimingTone.warn));
    });

    test('오늘 이미 끝났으면 회색 종료된 팝업', () {
      expect(timingBadge(popup, courseDate: DateTime(2026, 11, 28), today: DateTime(2026, 12, 1)), const TimingBadge('종료된 팝업', TimingTone.ended));
    });

    test('코스 날짜가 없으면 오늘 기준', () {
      expect(timingBadge(popup, today: DateTime(2026, 11, 29)), const TimingBadge('팝업 · 오늘 종료', TimingTone.normal));
    });

    test('행사도 같은 규칙', () {
      final event = PlaceTiming.fromJson({'kind': 'event', 'start_date': '2026-10-28', 'end_date': '2026-12-20'});
      expect(timingBadge(event, courseDate: DateTime(2026, 11, 22), today: today), const TimingBadge('행사 · 12/20까지', TimingTone.normal));
    });

    test('신규 오픈: 날짜 있으면 붙이고, 90일 지나면 숨김', () {
      final dated = PlaceTiming.fromJson({'kind': 'new_opening', 'start_date': '2026-11-11', 'end_date': ''});
      final undated = PlaceTiming.fromJson({'kind': 'new_opening', 'start_date': '', 'end_date': '', 'checked_on': '2026-11-15'});
      expect(timingBadge(dated, today: today), const TimingBadge('신규 오픈 · 11/11', TimingTone.fresh));
      expect(timingBadge(undated, today: today), const TimingBadge('신규 오픈', TimingTone.fresh));
      expect(timingBadge(dated, today: DateTime(2027, 3, 1)), isNull);
      expect(timingBadge(undated, today: DateTime(2027, 3, 1)), isNull);
    });

    test('기간 정보가 없으면 태그 없음', () {
      expect(timingBadge(null, today: today), isNull);
    });
  });

  group('장소 상세 기간 줄', () {
    test('팝업: 요일 붙은 기간 + 확인한 날', () {
      final p = timingPeriod(popup, today: today)!;
      expect(p.label, '기간');
      expect(p.value, '11.11 (수) ~ 11.29 (일)');
      expect(p.note, '팝업 · 웹 글에서 날짜를 확인했어요 (11/15)');
      expect(p.tip, timingVisitTip);
      expect(p.ended, isFalse);
    });

    test('끝난 팝업', () {
      final p = timingPeriod(popup, today: DateTime(2026, 12, 1))!;
      expect(p.note, '종료된 팝업이에요');
      expect(p.tip, isNull); // 끝난 곳엔 방문 안내를 붙이지 않는다
      expect(p.ended, isTrue);
    });

    test('신규 오픈은 날짜가 있을 때만', () {
      final dated = PlaceTiming.fromJson({'kind': 'new_opening', 'start_date': '2026-11-11', 'end_date': ''});
      final undated = PlaceTiming.fromJson({'kind': 'new_opening', 'start_date': '', 'end_date': ''});
      expect(timingPeriod(dated, today: today)!.value, '11.11 (수)');
      expect(timingPeriod(dated, today: today)!.label, '오픈');
      expect(timingPeriod(dated, today: today)!.tip, isNull);
      expect(timingPeriod(undated, today: today), isNull);
    });
  });
}
