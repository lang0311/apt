import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/states.dart';
import '../../../../core/widgets/overlays.dart';
import '../../../../core/widgets/surfaces.dart';
import '../../../party/domain/party_models.dart';
import '../../../party/presentation/widgets/party_avatar_stack.dart';
import '../../../place/domain/place_timing.dart';
import '../../../place/presentation/widgets/timing_tag.dart';
import '../../domain/course_models.dart';
import 'course_place_row.dart';
import 'course_route_map.dart';

/// 코스 머리: 이름 + 한 줄 정보 (상세 · 4단계 결과 · 편집이 같은 모양)
class CourseHero extends StatelessWidget {
  const CourseHero({super.key, required this.title, this.meta, this.dday, this.savedNotice = false});

  final String title;

  /// 제목 아래 한 줄 (요약 칸 [CourseStats]을 쓰는 화면은 비운다)
  final String? meta;

  /// 다가오는 코스의 D-day (날짜에서 계산한 값)
  final String? dday;

  /// 저장하고 바로 들어왔을 때만 보이는 "코스가 저장되었어요"
  final bool savedNotice;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xxs, AppSpacing.screenH, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (savedNotice) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
              decoration: BoxDecoration(color: AppColors.successSoft, borderRadius: AppRadius.pillAll),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_rounded, size: 14, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text('코스가 저장되었어요', style: AppTypography.caption.copyWith(color: AppColors.success, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (dday != null) ...[
            Text(dday!, style: AppTypography.label.copyWith(color: AppColors.primary)),
            const SizedBox(height: 2),
          ],
          Text(title, style: AppTypography.hero),
          if (meta != null && meta!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(meta!, style: AppTypography.meta),
          ],
        ],
      ),
    );
  }
}

/// 일정 머리(범례) 아래 한 줄: "자연 · 미식 취향을 반영했어요", 파티 코스는 "파티원 3명의 미식 …",
/// 파티원이 공유한 단어가 없으면 "파티원 3명의 취향을 반영했어요" (07 D46).
/// 파티 코스에 장소별로 맞는 파티원 정보가 있고 파티원 이름을 알면 그 아래 파란 링크 "누구 취향인지 보기"를 두고,
/// 누르면 바텀시트에 일정 순서대로 장소와 그 장소가 맞는 파티원 이름을 보여 준다(07 D57 — 카드 안의 막대 대신 한 겹).
/// ✦ · 주황은 AI 추천 장소 표시 전용이라 쓰지 않는다(D17). 넘치면 말줄임.
class AppliedTasteLine extends StatelessWidget {
  const AppliedTasteLine({super.key, required this.taste, this.stops = const [], this.members});
  final AppliedTaste taste;

  /// 지금 일정 (시트 목록의 순서와 범위)
  final List<CourseStop> stops;

  /// 파티원 (서버 순서, 얼굴 색 순서와 같음). 없으면 링크 없이 한 줄만
  final List<PartyMember>? members;

  List<TextSpan> get _spans {
    const strong = TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700);
    final words = taste.words.join(' · ');
    return taste.words.isEmpty
        ? [TextSpan(text: '파티원 ${taste.memberCount}명', style: strong), const TextSpan(text: '의 취향을 반영했어요')]
        : [
            if (taste.memberCount > 1) TextSpan(text: '파티원 ${taste.memberCount}명의 '),
            TextSpan(text: words, style: strong),
            const TextSpan(text: ' 취향을 반영했어요'),
          ];
  }

  Widget _text(List<TextSpan> spans, {int maxLines = 1}) =>
      Text.rich(TextSpan(children: spans), style: AppTypography.meta, maxLines: maxLines, overflow: TextOverflow.ellipsis);

  @override
  Widget build(BuildContext context) {
    final spans = _spans;
    final m = members;
    final rows = m == null || !taste.hasDetail ? const <Widget>[] : _detailRows(m);
    final line = Semantics(label: spans.map((s) => s.text).join(), excludeSemantics: true, child: _text(spans));
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, rows.isEmpty ? AppSpacing.xs : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          line,
          if (rows.isNotEmpty)
            Semantics(
              button: true,
              label: '장소마다 누구 취향인지 보기',
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.small),
                onTap: () => _openSheet(context, spans, rows),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 36),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: 1,
                    child: Text('누구 취향인지 보기', style: AppTypography.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openSheet(BuildContext context, List<TextSpan> spans, List<Widget> rows) {
    showAppBottomSheet<void>(
      context,
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xs, AppSpacing.screenH, AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('장소마다 누구 취향인지', style: AppTypography.cardTitle),
            const SizedBox(height: 2),
            _text(spans, maxLines: 2),
            const SizedBox(height: AppSpacing.xs),
            ...rows,
          ],
        ),
      ),
    );
  }

  /// 일정 순서대로 "장소 이름 · 맞는 파티원", 맨 아래 반영되지 못한 파티원
  List<Widget> _detailRows(List<PartyMember> members) {
    final index = {for (final (i, m) in members.indexed) m.id: i};
    String name(PartyMember m) => m.isMe ? '나' : m.nickname;
    final rows = <Widget>[];
    for (final stop in stops) {
      final ids = {...?taste.matches[stop.place.id]}.where(index.containsKey).toSet();
      if (ids.isEmpty) continue;
      final everyone = ids.length == members.length;
      final who = [for (final m in members) if (ids.contains(m.id)) m];
      rows.add(_DetailRow(
        semantics: '${stop.place.name}, ${everyone ? '모두' : who.map(name).join(', ')}',
        child: Row(
          children: [
            Expanded(flex: 3, child: Text(stop.place.name, style: AppTypography.label.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: AppSpacing.xs),
            // 이름은 오른쪽 끝에 붙인다
            Expanded(
              flex: 2,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: everyone
                    ? [Text('모두', style: AppTypography.meta.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700))]
                    : [
                        for (final m in who)
                          Text(name(m), style: AppTypography.meta.copyWith(color: PartyAvatarStack.nameColor(index[m.id]!), fontWeight: FontWeight.w700)),
                      ],
              ),
            ),
          ],
        ),
      ));
    }
    for (final gap in taste.gaps) {
      final member = members.where((m) => m.id == gap.memberId).firstOrNull;
      if (member == null) continue;
      final text = switch ((member.isMe, gap.noHistory)) {
        (true, true) => '저장한 장소가 없어 내 취향은 반영하지 못했어요',
        (true, false) => '내 취향에 잘 맞는 장소는 찾지 못했어요',
        (false, true) => '${withTopicParticle(member.nickname)} 저장한 장소가 없어 반영하지 못했어요',
        (false, false) => '${member.nickname} 취향에 잘 맞는 장소는 찾지 못했어요',
      };
      rows.add(_DetailRow(semantics: text, child: Text(text, style: AppTypography.caption)));
    }
    return rows;
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.semantics, required this.child});
  final String semantics;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
        label: semantics,
        excludeSemantics: true,
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
          child: child,
        ),
      );
}

/// "10월 22일 (목) · 오전 11:00 출발"
String courseMetaLine({DateTime? date, TimeOfDay? start}) => [
      if (date != null) formatMonthDayWeekday(date),
      if (start != null) '${formatTimeOfDay(start)} 출발',
    ].join(' · ');

/// 장소 사이 직선 거리 합(m). 팀 서버 `distance_km`와 같은 방식(`route_type: straight_line`)이라 편집 뒤에도 앱에서 다시 센다.
/// 좌표가 있는 장소가 둘보다 적으면 null
int? straightDistanceMeters(List<CourseStop> stops) {
  final points = [for (final s in stops) if (s.place.location != null) s.place.location!];
  if (points.length < 2) return null;
  var sum = 0.0;
  for (var i = 1; i < points.length; i++) {
    sum += points[i - 1].distanceTo(points[i]);
  }
  return sum.round();
}

/// 코스 요약 칸: 날짜 · 출발 · 거리. 값이 있는 칸만 보여 주고(2칸, 1칸), 하나도 없으면 그리지 않는다
class CourseStats extends StatelessWidget {
  const CourseStats({super.key, this.date, this.start, this.stops = const []});
  final DateTime? date;
  final TimeOfDay? start;
  final List<CourseStop> stops;

  @override
  Widget build(BuildContext context) {
    final meters = straightDistanceMeters(stops);
    final cells = <(String, String)>[
      if (date != null) ('날짜', '${date!.month}.${date!.day} (${weekdayLabel(date!)})'),
      if (start != null) ('출발', formatTimeOfDay(start!)),
      if (meters != null) ('직선 거리', formatDistance(meters)),
    ];
    if (cells.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.thumb),
        border: Border.all(color: AppColors.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, (label, value)) in cells.indexed) ...[
              if (i > 0) const VerticalDivider(width: 1, thickness: 1, indent: 12, endIndent: 12, color: AppColors.divider),
              Expanded(
                child: Semantics(
                  label: '$label $value',
                  excludeSemantics: true,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 10, AppSpacing.xs, 11),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: AppTypography.caption),
                        const SizedBox(height: 2),
                        Text(value, style: AppTypography.bodyStrong.copyWith(fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 일정 제목 아래 한 줄: 진한 원 "내가 고른 곳 n", 주황 ✦ "AI 추천 n" (없는 쪽은 뺀다)
class CourseStopLegend extends StatelessWidget {
  const CourseStopLegend({super.key, required this.stops});
  final List<CourseStop> stops;

  @override
  Widget build(BuildContext context) {
    final ai = stops.where((s) => s.isAi).length;
    final mine = stops.length - ai;
    Widget item(Widget dot, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [dot, const SizedBox(width: 6), Text(text, style: AppTypography.caption.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w700))],
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(SectionCard.innerPadding, 0, SectionCard.innerPadding, AppSpacing.xs),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: 4,
        children: [
          if (mine > 0)
            item(Container(width: 12, height: 12, decoration: const BoxDecoration(color: AppColors.ink, shape: BoxShape.circle)), '내가 고른 곳 $mine'),
          if (ai > 0)
            item(
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(color: AppColors.ai, shape: BoxShape.circle),
                child: const Icon(Icons.auto_awesome, size: 8, color: Colors.white),
              ),
              'AI 추천 $ai',
            ),
        ],
      ),
    );
  }
}

/// 일정 카드 제목 줄의 "편집" 버튼 (테두리 있는 작은 버튼, 누르는 영역 44)
class CourseEditButton extends StatelessWidget {
  const CourseEditButton({super.key, required this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: Material(
        color: AppColors.surfaceRaised,
        shape: const StadiumBorder(side: BorderSide(color: AppColors.border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32, minWidth: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.edit_outlined, size: 14, color: AppColors.textPrimary),
                  const SizedBox(width: 4),
                  Text('편집', style: AppTypography.meta.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 장소 번호 원. 내가 고른 장소 = 진한 번호, AI 추천 = 주황 ✦.
Widget _marker(CourseStop stop, int? number) => StopMarker(source: stop.source, number: number);

/// 장소 이름 아래 줄: 카테고리 · 지역. AI 추천 여부는 번호 원(주황 ✦)으로 구분하고,
/// 추천 이유는 장소를 눌렀을 때 시트의 '추천 이유 보기'에서 보여 준다 (07 D40).
class _StopText extends StatelessWidget {
  const _StopText({required this.stop, this.prefix, this.changed = false, this.courseDate});
  final CourseStop stop;
  final String? prefix;
  final DateTime? courseDate;

  /// 다시 추천으로 바뀐 장소 — 이름 옆에 작은 '바뀜' (주황은 AI 추천 장소 표시라 써도 된다, 07 D17 · D60)
  final bool changed;

  @override
  Widget build(BuildContext context) {
    final place = stop.place;
    final area = place.shortArea;
    final sub = [place.categoryLabel, if (area.isNotEmpty) area].join(' · ');
    final timing = timingBadge(place.timing, courseDate: courseDate);
    final subLine = Text.rich(
      TextSpan(children: [
        if (prefix != null)
          TextSpan(text: '$prefix · ', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
        TextSpan(text: sub),
      ]),
      style: AppTypography.caption,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(child: Text(place.name, style: AppTypography.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (changed) ...[
              const SizedBox(width: 6),
              Text('바뀜', style: AppTypography.caption.copyWith(color: AppColors.aiText, fontWeight: FontWeight.w800)),
            ] else if (stop.isAi) ...[
              // 번호가 끊기지 않게 바뀐 뒤로 AI 추천 곳은 주황 번호와 이 작은 표시로 구분한다
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: AppColors.aiSoft, borderRadius: BorderRadius.circular(AppRadius.tiny)),
                child: Text('AI 추천', style: AppTypography.caption.copyWith(color: AppColors.aiText, fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 1),
        // 팝업 · 행사 · 신규 오픈은 카테고리 줄 맨 앞에 작은 태그 (서버 API 1번)
        if (timing == null)
          subLine
        else
          Row(
            children: [
              TimingTag(timing),
              const SizedBox(width: 6),
              Flexible(child: subLine),
            ],
          ),
      ],
    );
  }
}


/// 일정 타임라인 (보는 상태). 번호 원을 한 줄기 선으로 잇고, 행 사이에 이동 정보를 둔다.
/// 코스 상세와 4단계 결과가 같은 위젯을 쓴다.
class CourseTimeline extends StatelessWidget {
  const CourseTimeline({
    super.key,
    required this.stops,
    this.onTapStop,
    this.onMore,
    this.highlightIds = const {},
    this.loadingIds = const {},
    this.courseDate,
  });

  final List<CourseStop> stops;

  /// 코스 날짜. 팝업 · 행사가 그날 열려 있는지 볼 때 쓴다(없으면 오늘 기준)
  final DateTime? courseDate;
  final void Function(CourseStop stop)? onTapStop;

  /// AI 장소 행 끝의 ⋯ (없으면 표시하지 않음)
  final void Function(CourseStop stop)? onMore;

  /// 다시 추천으로 바뀐 장소 (주황 바탕)
  final Set<String> highlightIds;

  /// 다시 추천 중인 자리 (뼈대)
  final Set<String> loadingIds;

  @override
  Widget build(BuildContext context) {
    final numbers = userStopNumbers(stops);
    // 도착 시간이 하나도 없는 코스(서버가 시간을 안 줄 때)는 시간 칸을 접는다
    final showTime = stops.any((s) => s.arrivalTime != null);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < stops.length; i++) ...[
            if (loadingIds.contains(stops[i].place.id))
              _SkeletonTile(withTime: showTime)
            else
              _ViewTile(
                stop: stops[i],
                number: numbers[i],
                showTime: showTime,
                lineAbove: i > 0,
                lineBelow: i < stops.length - 1,
                highlighted: highlightIds.contains(stops[i].place.id),
                courseDate: courseDate,
                onTap: onTapStop == null ? null : () => onTapStop!(stops[i]),
                onMore: onMore == null || !stops[i].isAi ? null : () => onMore!(stops[i]),
              ),
            if (i < stops.length - 1) _LegRow(leg: stops[i].nextLeg, showTime: showTime),
          ],
        ],
      ),
    );
  }
}

class _ViewTile extends StatelessWidget {
  const _ViewTile({
    required this.stop,
    required this.number,
    this.showTime = true,
    this.highlighted = false,
    this.lineAbove = false,
    this.lineBelow = false,
    this.courseDate,
    this.onTap,
    this.onMore,
  });
  final CourseStop stop;
  final DateTime? courseDate;
  final bool lineAbove;
  final bool lineBelow;
  final int? number;
  final bool showTime;
  final bool highlighted;
  final VoidCallback? onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return _ChangedFlash(
      on: highlighted,
      child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.xs, 0, onMore == null ? AppSpacing.sm : 0, 0),
            child: IntrinsicHeight(
              child: Row(
              children: [
                if (showTime) ...[
                  Container(
                    width: 40,
                    alignment: Alignment.centerRight,
                    child: Text(
                      stop.arrivalTime == null ? '' : formatClock(stop.arrivalTime!),
                      textAlign: TextAlign.right,
                      style: AppTypography.caption.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                // 번호 원 위아래로 선을 이어 일정 전체가 한 줄기로 보이게
                Column(
                  children: [
                    Expanded(child: _Line(visible: lineAbove)),
                    _marker(stop, number),
                    Expanded(child: _Line(visible: lineBelow)),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Align(alignment: Alignment.centerLeft, child: _StopText(stop: stop, changed: highlighted, courseDate: courseDate)),
                  ),
                ),
                if (onMore != null)
                  IconButton(
                    tooltip: '${stop.place.name} 메뉴',
                    onPressed: onMore,
                    icon: const Icon(Icons.more_horiz_rounded, size: 20, color: AppColors.textSecondary),
                  ),
              ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

/// 다시 추천으로 바뀐 줄: 주황 바탕을 약 4초 보여 주고 옅어진다. 그 뒤에는 이름 옆 '바뀜'만 남는다(07 D60).
class _ChangedFlash extends StatefulWidget {
  const _ChangedFlash({required this.on, required this.child});
  final bool on;
  final Widget child;

  @override
  State<_ChangedFlash> createState() => _ChangedFlashState();
}

class _ChangedFlashState extends State<_ChangedFlash> with SingleTickerProviderStateMixin {
  // 4초 동안 그대로, 마지막 0.6초에 옅어진다
  late final AnimationController _c;
  late final CurvedAnimation _fade;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 4600));
    _fade = CurvedAnimation(parent: _c, curve: const Interval(4000 / 4600, 1, curve: Curves.easeOut));
    if (widget.on) _c.forward();
  }

  @override
  void didUpdateWidget(covariant _ChangedFlash old) {
    super.didUpdateWidget(old);
    if (widget.on && !old.on) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _fade.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.on) return widget.child;
    return AnimatedBuilder(
      animation: _fade,
      child: widget.child,
      builder: (_, child) => DecoratedBox(
        decoration: BoxDecoration(
          color: Color.lerp(AppColors.aiSoft, AppColors.aiSoft.withValues(alpha: 0), _fade.value),
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: child,
      ),
    );
  }
}

/// 장소 사이 이동 줄: 번호 원을 잇는 선 + "도보 6분" (이동 정보가 없으면 짧게)
class _LegRow extends StatelessWidget {
  const _LegRow({this.leg, this.showTime = true});
  final RouteLeg? leg;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: leg == null ? 6 : 26,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 시각(40) + 간격(8), 선은 번호 원(26) 가운데 — 글자는 장소 이름과 같은 자리에서 시작
          SizedBox(width: AppSpacing.xs + (showTime ? 40 + AppSpacing.xs : 0)),
          const _Line(visible: true),
          const SizedBox(width: 12),
          if (leg != null) ...[
            Icon(leg!.mode.icon, size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(leg!.label, style: AppTypography.caption),
          ],
        ],
      ),
    );
  }
}

/// 일정 줄기 (폭 2, 번호 원 가운데를 지난다)
class _Line extends StatelessWidget {
  const _Line({required this.visible});
  final bool visible;

  @override
  Widget build(BuildContext context) => Container(
        width: 2,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: visible ? AppColors.borderStrong : Colors.transparent,
      );
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile({this.withTime = false});
  final bool withTime;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 8),
      child: Row(
        children: [
          if (withTime) ...[
            const SizedBox(width: 40, child: Align(alignment: Alignment.centerRight, child: SkeletonBox(width: 30, height: 10, radius: 5))),
            const SizedBox(width: AppSpacing.xs),
          ] else
            const SizedBox(width: 24),
          const SkeletonBox(width: 26, height: 26, radius: 13),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(widthFactor: 0.6, child: SkeletonBox(height: 11, radius: 5)),
                SizedBox(height: 6),
                FractionallySizedBox(widthFactor: 0.35, child: SkeletonBox(height: 9, radius: 5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 일정 편집 목록 (손잡이 · 번호 · 이름 · X, 마지막 "장소 추가").
/// 카드 안에 흰 칸을 또 띄우지 않고 구분선으로 나눈 한 겹 목록이다(07 D57).
/// 시간과 이동 줄은 저장하거나 다시 추천하면 다시 계산되므로 편집 중에는 숨긴다.
class CourseEditList extends StatelessWidget {
  const CourseEditList({
    super.key,
    required this.stops,
    required this.onReorder,
    required this.onRemove,
    required this.onTapTile,
    this.onAdd,
    this.addedIds = const {},
    this.highlightIds = const {},
    this.loadingIds = const {},
    this.enabled = true,
  });

  final List<CourseStop> stops;
  final void Function(int oldIndex, int newIndex) onReorder;

  /// X — 언제나 "이번만" 빼기 (차단은 타일 시트에서만)
  final void Function(CourseStop stop) onRemove;
  final void Function(CourseStop stop, int index) onTapTile;
  final VoidCallback? onAdd;

  /// 방금 넣은 장소 (파란 테두리 + "새로 추가")
  final Set<String> addedIds;
  final Set<String> highlightIds;
  final Set<String> loadingIds;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final numbers = userStopNumbers(stops);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: stops.length,
            onReorder: enabled ? onReorder : (_, _) {},
            proxyDecorator: (child, _, _) => Material(
              color: AppColors.surfaceRaised,
              elevation: 6,
              shadowColor: AppColors.shadowFloat,
              borderRadius: BorderRadius.circular(AppRadius.medium),
              child: child,
            ),
            itemBuilder: (_, i) {
              final stop = stops[i];
              final id = stop.place.id;
              return Column(
                key: ValueKey(id),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (i > 0) const Divider(height: 1, indent: 40, endIndent: AppSpacing.xs, color: AppColors.divider),
                  loadingIds.contains(id)
                    ? const _SkeletonTile()
                    : _EditTile(
                        stop: stop,
                        index: i,
                        number: numbers[i],
                        added: addedIds.contains(id),
                        highlighted: highlightIds.contains(id),
                        enabled: enabled,
                        onRemove: () => onRemove(stop),
                        onTap: () => onTapTile(stop, i),
                      ),
                ],
              );
            },
          ),
          if (onAdd != null) ...[
            if (stops.isNotEmpty) const Divider(height: 1, indent: 40, endIndent: AppSpacing.xs, color: AppColors.divider),
            _AddTile(onTap: enabled ? onAdd : null),
          ],
        ],
      ),
    );
  }
}

class _EditTile extends StatelessWidget {
  const _EditTile({
    required this.stop,
    required this.index,
    required this.number,
    required this.added,
    required this.highlighted,
    required this.enabled,
    required this.onRemove,
    required this.onTap,
  });

  final CourseStop stop;
  final int index;
  final int? number;
  final bool added;
  final bool highlighted;
  final bool enabled;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.medium);
    return _ChangedFlash(
      on: highlighted,
      child: Material(
      color: added && !highlighted ? AppColors.primarySoft : Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: enabled ? onTap : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                enabled: enabled,
                child: const SizedBox(
                  width: 40,
                  height: 56,
                  child: Icon(Icons.drag_handle_rounded, color: AppColors.controlBorder, semanticLabel: '끌어서 순서 변경'),
                ),
              ),
              _marker(stop, number),
              const SizedBox(width: 10),
              Expanded(child: _StopText(stop: stop, prefix: added ? '새로 추가' : null, changed: highlighted)),
              IconButton(
                tooltip: '${stop.place.name} 빼기',
                onPressed: enabled ? onRemove : null,
                icon: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(color: AppColors.surfaceMuted, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              const SizedBox(width: 40),
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                child: const Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Text('장소 추가', style: AppTypography.bodyStrong.copyWith(color: AppColors.primary)),
            ],
          ),
        ),
      ),
    );
  }
}
