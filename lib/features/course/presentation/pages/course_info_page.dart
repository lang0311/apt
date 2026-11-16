import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/bottom_cta.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/chips.dart';
import '../../../../core/widgets/headers.dart';
import '../../../../core/widgets/inputs.dart';
import '../../../../core/widgets/states.dart';
import '../../../../core/widgets/surfaces.dart';
import '../../domain/course_models.dart';
import '../course_draft_controller.dart';
import '../course_providers.dart';
import '../widgets/course_when_sheet.dart';

/// #23 코스 기본 정보 (1/4): 이름 · 날짜(화면의 칩) · 출발 시간(휠 시트) · 분위기. 장소는 3단계에서만 보여 준다
class CourseInfoPage extends ConsumerStatefulWidget {
  const CourseInfoPage({super.key});

  @override
  ConsumerState<CourseInfoPage> createState() => _CourseInfoPageState();
}

class _CourseInfoPageState extends ConsumerState<CourseInfoPage> {
  late final _name = TextEditingController(text: ref.read(courseDraftProvider).name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  CourseDraftController get _draft => ref.read(courseDraftProvider.notifier);

  /// 날짜를 처음 고르면 출발 시간은 오전 11시로 채워 둔다 (시간 칸에서 바꾼다)
  void _pickDate(DateTime date) {
    FocusManager.instance.primaryFocus?.unfocus();
    _draft.update((d) => d.copyWith(date: date, startTime: d.startTime ?? const TimeOfDay(hour: 11, minute: 0)));
  }

  Future<void> _pickTime() async {
    // 시트를 닫으면 이전 포커스(코스 이름)가 돌아와 키보드가 다시 올라오지 않게 먼저 푼다
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await showCourseTimeSheet(context, time: ref.read(courseDraftProvider).startTime);
    if (picked != null) _draft.update((d) => d.copyWith(startTime: picked));
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(courseDraftProvider);
    final moods = ref.watch(moodOptionsProvider);
    // 서버가 분위기 목록을 주지 않으면(빈 목록) 분위기 영역 전체를 숨긴다 (팀 서버는 분위기 입력이 없다)
    final showMoods = !(moods.hasValue && moods.value!.isEmpty);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const StepHeader(step: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.lg, AppSpacing.screenH, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('어떤 코스를 만들까요?', style: AppTypography.title),
                        const SizedBox(height: AppSpacing.lg),
                        AppTextField(
                          controller: _name,
                          label: '코스 이름',
                          hint: '예: 가을 서울 카페 산책',
                          maxLength: 30,
                          onChanged: (v) => _draft.update((d) => d.copyWith(name: v)),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text('언제 떠나요', style: AppTypography.label),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                    ),
                  ),
                  // 날짜 칩은 화면 끝까지 넘긴다 (기간 여행은 정책 확정 후)
                  CourseDayChips(
                    selected: draft.date,
                    onPick: _pickDate,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PickerField(
                          label: '출발 시간',
                          icon: Icons.schedule_rounded,
                          value: draft.startTime == null ? null : formatTimeOfDay(draft.startTime!),
                          hint: '출발 시간을 골라 주세요',
                          onTap: _pickTime,
                        ),
                        if (showMoods) ...[
                          const SizedBox(height: AppSpacing.lg),
                          Text('여행 분위기', style: AppTypography.label),
                          const SizedBox(height: AppSpacing.xs),
                        ],
                      ],
                    ),
                  ),
                  // 분위기 칩은 개수와 상관없이 한 줄, 가로로 넘긴다 (서버 키워드 그대로)
                  if (showMoods) ...[
                    AsyncValueView(
                      value: moods,
                      compactError: true,
                      loading: const Padding(padding: AppSpacing.screenPadding, child: SkeletonBox(height: 36)),
                      onRetry: () => ref.invalidate(moodOptionsProvider),
                      data: (list) =>
                          _MoodRow(options: list, selected: draft.moodKeys, onToggle: (key) => _draft.update((d) => d.toggleMood(key))),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.sm, AppSpacing.screenH, 0),
                      child: Text('선택한 분위기는 추천에 반영돼요.', style: AppTypography.caption),
                    ),
                  ],
                ],
              ),
            ),
            BottomCta(
              child: AppButton(label: '다음', onPressed: draft.infoComplete ? () => context.push(AppRoutes.courseNewCompanion) : null),
            ),
          ],
        ),
      ),
    );
  }
}

/// 탭하면 피커가 열리는 필드 (아이콘 + 값 + ›)
class _PickerField extends StatelessWidget {
  const _PickerField({required this.label, required this.icon, required this.value, required this.hint, required this.onTap});
  final String label;
  final IconData icon;
  final String? value;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.label),
        const SizedBox(height: AppSpacing.xs),
        AppCard(
          onTap: onTap,
          radius: AppRadius.input,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 15),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  value ?? hint,
                  style: value == null ? AppTypography.bodyStrong.copyWith(color: AppColors.textSecondary) : AppTypography.bodyStrong,
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ],
    );
  }
}

/// 분위기 칩 한 줄 (가로 스크롤, 오른쪽 끝을 흐리게 해 더 있다는 걸 보여 준다).
/// 처음 열 때 고른 칩이 화면 밖에 있으면 그 칩이 보이게 넘긴다.
class _MoodRow extends StatefulWidget {
  const _MoodRow({required this.options, required this.selected, required this.onToggle});
  final List<MoodOption> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  State<_MoodRow> createState() => _MoodRowState();
}

class _MoodRowState extends State<_MoodRow> {
  final _firstSelected = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _firstSelected.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.5, duration: Duration.zero);
    });
  }

  @override
  Widget build(BuildContext context) {
    final firstKey = widget.options.where((m) => widget.selected.contains(m.key)).firstOrNull?.key;
    return SizedBox(
      height: AppSpacing.chipHeight + 2,
      child: ShaderMask(
        shaderCallback: (rect) =>
            const LinearGradient(colors: [Colors.black, Colors.black, Colors.transparent], stops: [0, 0.88, 1]).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: ChipScroller(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 0, AppSpacing.xxl, 0),
          children: [
            for (final m in widget.options)
              AppChip(
                key: m.key == firstKey ? _firstSelected : null,
                label: m.label,
                selected: widget.selected.contains(m.key),
                onTap: () => widget.onToggle(m.key),
              ),
          ],
        ),
      ),
    );
  }
}
