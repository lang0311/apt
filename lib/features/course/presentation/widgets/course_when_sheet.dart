import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/overlays.dart';

const _chipDays = 14;
const _minuteStep = 10;

/// 코스 만들기 1단계의 날짜 칩 한 줄: 오늘부터 2주 + 달력 칩(먼 날짜는 달력 팝업).
/// 달력에서 2주 뒤 날짜를 고르면 그 날짜를 맨 앞 칩으로 보여 준다.
class CourseDayChips extends StatelessWidget {
  const CourseDayChips({super.key, required this.selected, required this.onPick, this.padding = EdgeInsets.zero});
  final DateTime? selected;
  final ValueChanged<DateTime> onPick;
  final EdgeInsets padding;

  Future<void> _openCalendar(BuildContext context, DateTime today) async {
    final picked = await showDialog<DateTime>(
      context: context,
      useRootNavigator: true,
      barrierColor: AppColors.scrim,
      builder: (_) => _CalendarDialog(today: today, selected: selected ?? today.add(const Duration(days: 1))),
    );
    if (picked != null) onPick(picked);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = selected == null ? null : DateUtils.dateOnly(selected!);
    final lastChip = today.add(const Duration(days: _chipDays - 1));
    final far = picked != null && picked.isAfter(lastChip);

    return SizedBox(
      height: MediaQuery.textScalerOf(context).scale(62),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        children: [
          if (far) ...[
            _DayChip(top: '${picked.month}월 ${weekdayLabel(picked)}', date: picked, selected: true, wide: true, onTap: () {}),
            const SizedBox(width: AppSpacing.xs),
          ],
          for (var i = 0; i < _chipDays; i++) ...[
            _DayChip(
              top: switch (i) {
                0 => '오늘',
                1 => '내일',
                _ => weekdayLabel(today.add(Duration(days: i))),
              },
              date: today.add(Duration(days: i)),
              selected: picked == today.add(Duration(days: i)),
              onTap: () => onPick(today.add(Duration(days: i))),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          _CalendarChip(onTap: () => _openCalendar(context, today)),
        ],
      ),
    );
  }
}

/// 출발 시간 시트: 오전/오후 · 시 · 분 휠 (기본 오전 11:00)
Future<TimeOfDay?> showCourseTimeSheet(BuildContext context, {TimeOfDay? time}) {
  return showAppBottomSheet<TimeOfDay>(context, builder: (_) => _TimeSheet(initial: time));
}

class _TimeSheet extends StatefulWidget {
  const _TimeSheet({this.initial});
  final TimeOfDay? initial;

  @override
  State<_TimeSheet> createState() => _TimeSheetState();
}

class _TimeSheetState extends State<_TimeSheet> {
  late final TimeOfDay _start = widget.initial ?? const TimeOfDay(hour: 11, minute: 0);
  late bool _pm = _start.hour >= 12;
  late int _hour12 = _start.hour % 12 == 0 ? 12 : _start.hour % 12;
  late int _minute = (_start.minute ~/ _minuteStep) * _minuteStep;

  TimeOfDay get _time => TimeOfDay(hour: (_hour12 % 12) + (_pm ? 12 : 0), minute: _minute);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: Text('출발 시간', style: AppTypography.section)),
              IconButton(
                tooltip: '닫기',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _TimeWheel(
            pm: _pm,
            hour12: _hour12,
            minute: _minute,
            onPm: (v) => setState(() => _pm = v),
            onHour: (v) => setState(() => _hour12 = v),
            onMinute: (v) => setState(() => _minute = v),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(label: '${formatTimeOfDay(_time)} 출발', onPressed: () => Navigator.pop<TimeOfDay>(context, _time)),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.top, required this.date, required this.selected, required this.onTap, this.wide = false});
  final String top;
  final DateTime date;
  final bool selected;
  final bool wide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dayColor = selected
        ? Colors.white
        : switch (date.weekday) {
            DateTime.saturday => AppColors.primary,
            DateTime.sunday => AppColors.danger,
            _ => AppColors.textPrimary,
          };
    return Semantics(
      button: true,
      selected: selected,
      label: formatMonthDayWeekday(date),
      excludeSemantics: true,
      // v2: 회색 채움 칸, 고른 날은 잉크 채움 (테두리 없음)
      child: Material(
        color: selected ? AppColors.ink : AppColors.fill,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.input)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.input),
          child: SizedBox(
            width: wide ? 76 : 56,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(top, style: AppTypography.caption.copyWith(color: selected ? Colors.white : AppColors.textSecondary)),
                Text('${date.day}', style: AppTypography.cardTitle.copyWith(color: dayColor)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarChip extends StatelessWidget {
  const _CalendarChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // v2: 날짜 칩과 같은 회색 칸에 달력 아이콘만
    return Semantics(
      button: true,
      label: '달력에서 날짜 고르기',
      excludeSemantics: true,
      child: Material(
        color: AppColors.fill,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.input)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.input),
          child: const SizedBox(
            width: 56,
            child: Center(child: Icon(Icons.calendar_month_outlined, size: 22, color: AppColors.textPrimary)),
          ),
        ),
      ),
    );
  }
}

/// 오전/오후 · 시 · 분 휠 (위아래 한 칸씩 보이는 3줄)
class _TimeWheel extends StatefulWidget {
  const _TimeWheel({
    required this.pm,
    required this.hour12,
    required this.minute,
    required this.onPm,
    required this.onHour,
    required this.onMinute,
  });
  final bool pm;
  final int hour12;
  final int minute;
  final ValueChanged<bool> onPm;
  final ValueChanged<int> onHour;
  final ValueChanged<int> onMinute;

  @override
  State<_TimeWheel> createState() => _TimeWheelState();
}

class _TimeWheelState extends State<_TimeWheel> {
  static const _extent = 40.0;
  static final _minutes = [for (var m = 0; m < 60; m += _minuteStep) m];

  late final _ap = FixedExtentScrollController(initialItem: widget.pm ? 1 : 0);
  late final _hour = FixedExtentScrollController(initialItem: widget.hour12 - 1);
  late final _min = FixedExtentScrollController(initialItem: _minutes.indexOf(widget.minute));

  @override
  void dispose() {
    _ap.dispose();
    _hour.dispose();
    _min.dispose();
    super.dispose();
  }

  void _onHour(int index) {
    final next = index + 1;
    // 11시 ↔ 12시를 넘으면 오전/오후도 함께 넘긴다 (오전 11시 → 오후 12시 = 정오)
    if ((widget.hour12 == 11 && next == 12) || (widget.hour12 == 12 && next == 11)) {
      final pm = !widget.pm;
      widget.onPm(pm);
      _ap.animateToItem(pm ? 1 : 0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
    widget.onHour(next);
  }

  Widget _column({
    required double width,
    required FixedExtentScrollController controller,
    required List<String> items,
    required ValueChanged<int> onSelected,
    required String label,
  }) {
    return Semantics(
      label: label,
      child: SizedBox(
        width: width,
        child: CupertinoPicker(
          scrollController: controller,
          itemExtent: _extent,
          diameterRatio: 1.6,
          squeeze: 1.0,
          // 가운데 띠는 아래 Stack에서 한 번만 그린다
          selectionOverlay: const SizedBox.shrink(),
          onSelectedItemChanged: onSelected,
          children: [
            for (final v in items)
              Center(
                child: Text(v, style: AppTypography.section.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _extent * 3,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: _extent,
            decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(AppRadius.sm)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _column(width: 72, label: '오전 오후', controller: _ap, items: const ['오전', '오후'], onSelected: (i) => widget.onPm(i == 1)),
              _column(width: 64, label: '시', controller: _hour, items: [for (var h = 1; h <= 12; h++) '$h'], onSelected: _onHour),
              Text(':', style: AppTypography.section),
              _column(
                width: 64,
                label: '분',
                controller: _min,
                items: [for (final m in _minutes) m.toString().padLeft(2, '0')],
                onSelected: (i) => widget.onMinute(_minutes[i]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 먼 날짜용 달력 팝업. 날짜를 누르면 바로 닫힌다.
class _CalendarDialog extends StatefulWidget {
  const _CalendarDialog({required this.today, required this.selected});
  final DateTime today;
  final DateTime selected;

  @override
  State<_CalendarDialog> createState() => _CalendarDialogState();
}

class _CalendarDialogState extends State<_CalendarDialog> {
  late DateTime _month = DateTime(widget.selected.year, widget.selected.month);

  bool get _canGoBack => _month.isAfter(DateTime(widget.today.year, widget.today.month));

  void _shift(int months) => setState(() => _month = DateTime(_month.year, _month.month + months));

  @override
  Widget build(BuildContext context) {
    final first = _month.weekday % 7; // 일요일 시작
    final days = DateUtils.getDaysInMonth(_month.year, _month.month);

    return Dialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xl),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.sm, AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: Text('${_month.year}년 ${_month.month}월', style: AppTypography.section)),
                _RoundIconButton(icon: Icons.chevron_left_rounded, tooltip: '이전 달', onPressed: _canGoBack ? () => _shift(-1) : null),
                const SizedBox(width: AppSpacing.xxs),
                _RoundIconButton(icon: Icons.chevron_right_rounded, tooltip: '다음 달', onPressed: () => _shift(1)),
                IconButton(
                  tooltip: '닫기',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Row(
              children: [
                for (final (i, weekday) in const ['일', '월', '화', '수', '목', '금', '토'].indexed)
                  Expanded(
                    child: Center(
                      child: Text(
                        weekday,
                        style: AppTypography.meta.copyWith(
                          fontWeight: FontWeight.w700,
                          color: switch (i) {
                            0 => AppColors.danger,
                            6 => AppColors.primary,
                            _ => AppColors.textSecondary,
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            // 달마다 줄 수가 달라 팝업 높이가 흔들리지 않게 항상 6줄
            for (var row = 0; row < 6; row++)
              Row(children: [for (var col = 0; col < 7; col++) Expanded(child: _dayCell(row * 7 + col - first + 1, days))]),
            const Divider(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(child: Text('파란 테두리가 오늘이에요', style: AppTypography.meta)),
                AppButton(
                  label: '오늘로',
                  variant: AppButtonVariant.soft,
                  expand: false,
                  height: 36,
                  onPressed: () => setState(() => _month = DateTime(widget.today.year, widget.today.month)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayCell(int day, int daysInMonth) {
    if (day < 1 || day > daysInMonth) return const SizedBox(height: 44);
    final date = DateTime(_month.year, _month.month, day);
    final past = date.isBefore(widget.today);
    final isToday = date == widget.today;
    final isSelected = date == widget.selected;
    final Color color;
    if (isSelected) {
      color = Colors.white;
    } else if (past) {
      color = AppColors.textHint;
    } else {
      color = switch (date.weekday) {
        DateTime.sunday => AppColors.danger,
        DateTime.saturday => AppColors.primary,
        _ => AppColors.textPrimary,
      };
    }
    return SizedBox(
      height: 44,
      child: Center(
        child: Semantics(
          button: !past,
          selected: isSelected,
          label: formatMonthDayWeekday(date),
          excludeSemantics: true,
          child: InkResponse(
            onTap: past ? null : () => Navigator.pop(context, date),
            radius: 22,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : null,
                border: isToday && !isSelected ? Border.all(color: AppColors.primary, width: 1.5) : null,
              ),
              child: Text(
                '$day',
                style: AppTypography.bodyStrong.copyWith(
                  color: color,
                  fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.tooltip, required this.onPressed});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.surfaceMuted,
        disabledBackgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        fixedSize: const Size(36, 36),
        minimumSize: const Size(36, 36),
      ),
      icon: Icon(icon, size: 20),
    );
  }
}
