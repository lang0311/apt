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
import '../../../../core/widgets/headers.dart';
import '../../../../core/widgets/inputs.dart';
import '../course_draft_controller.dart';
import '../widgets/course_when_sheet.dart';

/// #23 코스 기본 정보 (1/4, v2): 이름 · 날짜(화면의 칩) · 출발 시간(휠 시트). 분위기 칩은 뺐다(서버가 추천 입력으로 받지 않음,
/// 2026-11-21 사용자 결정 — `CourseDraft.moodKeys` 데이터는 남김). 장소는 3단계에서만 보여 준다
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
                        Text('어떤 코스를 만들까요?', style: AppTypography.display),
                        const SizedBox(height: AppSpacing.lg),
                        AppTextField(
                          controller: _name,
                          label: '코스 이름',
                          hint: '예: 가을 서울 카페 산책',
                          maxLength: 30,
                          onChanged: (v) => _draft.update((d) => d.copyWith(name: v)),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text('언제 떠나요', style: AppTypography.labelLarge.copyWith(color: AppColors.textSecondary)),
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
                      ],
                    ),
                  ),
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
    // v2: 입력칸과 같은 회색 채움 칸(52), 값은 왼쪽 · 시계 아이콘은 오른쪽
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.labelLarge.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.xs),
        Material(
          color: AppColors.fill,
          borderRadius: BorderRadius.circular(AppRadius.input),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.input),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSpacing.inputHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        value ?? hint,
                        style: value == null ? AppTypography.body.copyWith(color: AppColors.textSecondary) : AppTypography.bodyStrong,
                      ),
                    ),
                    Icon(icon, color: AppColors.textSecondary, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 분위기 칩 한 줄 (가로 스크롤, 오른쪽 끝을 흐리게 해 더 있다는 걸 보여 준다).
