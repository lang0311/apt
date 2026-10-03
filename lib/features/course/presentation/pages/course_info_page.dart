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
import '../course_draft_controller.dart';
import '../course_providers.dart';

/// #23 코스 기본 정보 (1/4): 이름 · 날짜 · 시작 시간 · 분위기
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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final current = ref.read(courseDraftProvider).date;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365 * 2)),
      helpText: '여행 날짜',
    );
    if (picked != null) _draft.update((d) => d.copyWith(date: picked));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: ref.read(courseDraftProvider).startTime ?? const TimeOfDay(hour: 11, minute: 0),
      helpText: '시작 시간',
    );
    if (picked != null) _draft.update((d) => d.copyWith(startTime: picked));
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(courseDraftProvider);
    final moods = ref.watch(moodOptionsProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const StepHeader(title: '코스 만들기', step: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.lg, AppSpacing.screenH, AppSpacing.lg),
                children: [
                  Text('어떤 여행을 만들까요?', style: AppTypography.title),
                  const SizedBox(height: 4),
                  Text('기본 정보를 바탕으로 일정과 추천을 준비해요.', style: AppTypography.body),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    controller: _name,
                    label: '코스 이름',
                    hint: '예: 가을 서울 카페 산책',
                    prefixIcon: Icons.edit_outlined,
                    maxLength: 30,
                    onChanged: (v) => _draft.update((d) => d.copyWith(name: v)),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _PickerField(
                    label: '여행 날짜',
                    icon: Icons.calendar_today_outlined,
                    // 기간(여러 날) 여행은 정책/디자인 확정 후 지원
                    value: draft.date == null ? null : '${formatDate(draft.date!)} · 하루',
                    hint: '날짜를 선택해주세요',
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _PickerField(
                    label: '시작 시간',
                    icon: Icons.schedule_rounded,
                    value: draft.startTime == null ? null : formatTimeOfDay(draft.startTime!),
                    hint: '시간을 선택해주세요',
                    onTap: _pickTime,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text('여행 분위기', style: AppTypography.label),
                  const SizedBox(height: AppSpacing.sm),
                  AsyncValueView(
                    value: moods,
                    compactError: true,
                    loading: const SkeletonBox(height: 36),
                    onRetry: () => ref.invalidate(moodOptionsProvider),
                    data: (list) => Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final m in list)
                          AppChip(
                            label: m.label,
                            selected: draft.moodKeys.contains(m.key),
                            onTap: () => _draft.update((d) => d.toggleMood(m.key)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const InfoCard(
                    icon: Icons.auto_awesome,
                    iconColor: AppColors.ai,
                    background: AppColors.aiSoft,
                    title: 'AI 추천에 활용돼요',
                    description: '여행 시간과 분위기에 맞춰 비는 동선을 채워드려요.\n파티 코스라면 참여자 취향도 함께 반영해요.',
                  ),
                ],
              ),
            ),
            BottomCta(
              child: AppButton(
                label: '다음: 저장한 장소 선택',
                onPressed: draft.infoComplete ? () => context.push(AppRoutes.courseNewPlaces) : null,
              ),
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
                  style: value == null ? AppTypography.bodyStrong.copyWith(color: AppColors.textHint) : AppTypography.bodyStrong,
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
