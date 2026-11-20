import '../../../core/utils/formatters.dart';

/// 팝업 · 행사 · 신규 오픈처럼 기간이 있는 장소 (팀 서버 `temporal`, 서버 API 1번).
/// 서버는 웹 글 본문에 날짜가 그대로 적힌 경우만 날짜를 채운다. 그래서 신규 오픈은 날짜가 없는 경우가 많다.
enum PlaceTimingKind { popup, event, newOpening }

class PlaceTiming {
  const PlaceTiming({required this.kind, this.start, this.end, this.checkedOn});

  final PlaceTimingKind kind;
  final DateTime? start;
  final DateTime? end;

  /// 서버가 웹 글로 확인한 날
  final DateTime? checkedOn;

  String get kindLabel => switch (kind) {
        PlaceTimingKind.popup => '팝업',
        PlaceTimingKind.event => '행사',
        PlaceTimingKind.newOpening => '신규 오픈',
      };

  bool get isLimited => kind != PlaceTimingKind.newOpening;

  /// 서버 값을 읽는다. `place`(일반 장소) · 모르는 종류 · 값 없음은 null.
  /// 팝업 · 행사인데 끝 날짜가 없으면 기간을 말할 수 없어서 표시하지 않는다(null)
  static PlaceTiming? fromJson(Object? json) {
    if (json is! Map) return null;
    final kind = switch (json['kind']) {
      'popup' => PlaceTimingKind.popup,
      'event' => PlaceTimingKind.event,
      'new_opening' => PlaceTimingKind.newOpening,
      _ => null,
    };
    if (kind == null) return null;
    final start = _date(json['start_date']);
    final end = _date(json['end_date']);
    if (kind != PlaceTimingKind.newOpening && end == null) return null;
    return PlaceTiming(kind: kind, start: start, end: end, checkedOn: _date(json['checked_on']));
  }

  static DateTime? _date(Object? value) {
    if (value is! String || value.length < 10) return null;
    final d = DateTime.tryParse(value.substring(0, 10));
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }
}

/// 일정 줄 태그의 색
enum TimingTone {
  /// 남색 글자 + 회색 바탕 (팝업 · 행사)
  normal,

  /// 초록 글자 (신규 오픈)
  fresh,

  /// 빨강 (코스 날짜엔 이미 끝났거나 아직 시작 전)
  warn,

  /// 회색 (저장한 코스에서 시간이 지나 끝남)
  ended,
}

class TimingBadge {
  const TimingBadge(this.text, this.tone);
  final String text;
  final TimingTone tone;

  @override
  bool operator ==(Object other) => other is TimingBadge && other.text == text && other.tone == tone;

  @override
  int get hashCode => Object.hash(text, tone);

  @override
  String toString() => 'TimingBadge($text, $tone)';
}

/// 신규 오픈을 '신규'로 보여 주는 기간 (서버 `novelty_score`도 90일 넘으면 0)
const newOpeningDays = 90;

String _md(DateTime d) => '${d.month}/${d.day}';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// 일정 줄 태그 문구. [courseDate]가 있으면 그날 기준으로 끝났는지 본다(서버는 '오늘' 기준으로만 거른다).
/// 표시할 게 없으면 null.
/// - 팝업 · 11/29까지 / 팝업 · 당일 종료 / (빨강) 팝업 · 11/22 종료 / (빨강) 팝업 · 12/1 시작 / (회색) 종료된 팝업
/// - 신규 오픈 · 11/11 / 신규 오픈 (확인한 지 90일이 지나면 숨김)
TimingBadge? timingBadge(PlaceTiming? timing, {DateTime? courseDate, DateTime? today}) {
  if (timing == null) return null;
  final now = _day(today ?? DateTime.now());
  final label = timing.kindLabel;
  if (timing.kind == PlaceTimingKind.newOpening) {
    final since = timing.start ?? timing.checkedOn;
    if (since != null && now.difference(since).inDays > newOpeningDays) return null;
    return TimingBadge(timing.start == null ? label : '$label · ${_md(timing.start!)}', TimingTone.fresh);
  }
  final end = timing.end!;
  if (now.isAfter(end)) return TimingBadge('종료된 $label', TimingTone.ended);
  final on = courseDate == null ? now : _day(courseDate);
  if (on.isAfter(end)) return TimingBadge('$label · ${_md(end)} 종료', TimingTone.warn);
  if (timing.start != null && on.isBefore(timing.start!)) return TimingBadge('$label · ${_md(timing.start!)} 시작', TimingTone.warn);
  if (on == end) return TimingBadge('$label · ${courseDate == null ? '오늘' : '당일'} 종료', TimingTone.normal);
  return TimingBadge('$label · ${_md(end)}까지', TimingTone.normal);
}

/// 장소 상세 '기간' 줄 (label · 값 · 아래 작은 글씨). 표시할 게 없으면 null
/// [tip]: 진행 중인 팝업 · 행사에만 붙는 방문 안내 (서버가 찾은 기간이 그날 운영 · 입장 · 예약을 보장하지 않음, 팀 추천 정책 문서)
typedef TimingPeriod = ({String label, String value, String note, String? tip, bool ended});

const timingVisitTip = '방문 전 운영시간·예약 여부를 확인해 주세요.';

String _mdw(DateTime d) => '${d.month}.${d.day} (${weekdayLabel(d)})';

/// - 팝업 · 행사: 기간 `11.11 (수) ~ 11.29 (일)` / `팝업 · 웹 글에서 날짜를 확인했어요 (11/15)`, 끝났으면 `종료된 팝업이에요`
/// - 신규 오픈(날짜 있을 때만): 오픈 `11.11 (화)` / `신규 오픈 · 웹 글에서 날짜를 확인했어요 (11/15)`
TimingPeriod? timingPeriod(PlaceTiming? timing, {DateTime? today}) {
  if (timing == null) return null;
  final now = _day(today ?? DateTime.now());
  final checked = timing.checkedOn == null ? '' : ' (${_md(timing.checkedOn!)})';
  final note = '${timing.kindLabel} · 웹 글에서 날짜를 확인했어요$checked';
  if (timing.kind == PlaceTimingKind.newOpening) {
    final start = timing.start;
    if (start == null || now.difference(start).inDays > newOpeningDays) return null;
    return (label: '오픈', value: _mdw(start), note: note, tip: null, ended: false);
  }
  final end = timing.end!;
  final value = timing.start == null ? '~ ${_mdw(end)}' : '${_mdw(timing.start!)} ~ ${_mdw(end)}';
  final ended = now.isAfter(end);
  return (
    label: '기간',
    value: value,
    note: ended ? '종료된 ${timing.kindLabel}이에요' : note,
    tip: ended ? null : timingVisitTip,
    ended: ended,
  );
}
