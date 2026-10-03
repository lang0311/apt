import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/external_link.dart';
import '../../../../core/widgets/bottom_cta.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/headers.dart';
import '../../../../core/widgets/staged_loading.dart';
import '../../../../core/widgets/states.dart';
import '../../../../core/widgets/surfaces.dart';
import '../../../saved/presentation/widgets/collection_picker_sheet.dart';
import '../../domain/extraction_models.dart';
import '../extraction_providers.dart';
import '../widgets/extracted_place_card.dart';

/// #11 추출 결과 검토. 공유로 들어오면 링크 입력(#10)을 건너뛰고 여기서 분석을 자동 시작한다.
///
/// 디자인이 없는 상태(진행 중/실패/비공개/장소 없음)는 공통 Loading/Empty/Error 컴포넌트로 임시 구현.
class ExtractionResultPage extends ConsumerWidget {
  const ExtractionResultPage({super.key, required this.url, this.fromShare = false});
  final String url;
  final bool fromShare;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(extractionProvider(url));
    final count = result.value?.places.length;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SubPageHeader(
              title: '추출 결과 확인',
              onBack: () => context.canPop() ? context.pop() : context.go(AppRoutes.extract),
              trailing: count == null || count == 0
                  ? null
                  : Text('$count곳 발견', style: AppTypography.label.copyWith(color: AppColors.primary)),
            ),
            Expanded(
              child: result.when(
                loading: () => StagedLoading(messages: [
                  fromShare ? '공유한 게시물을 불러오고 있어요' : '게시물을 불러오고 있어요',
                  '게시물에서 장소를 찾고 있어요',
                  '장소 정보를 확인하고 있어요',
                ]),
                error: (e, _) => _Failure(
                  kind: e is ExtractionFailure ? e.kind : ExtractionFailureKind.failed,
                  onRetry: () => ref.invalidate(extractionProvider(url)),
                ),
                data: (r) => r.places.isEmpty
                    ? _Failure(kind: ExtractionFailureKind.noPlaceFound, onRetry: () => ref.invalidate(extractionProvider(url)))
                    : _Review(result: r),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.kind, required this.onRetry});
  final ExtractionFailureKind kind;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final retryable = kind == ExtractionFailureKind.failed;
    return Center(
      child: SingleChildScrollView(
        child: AppEmptyState(
          icon: switch (kind) {
            ExtractionFailureKind.privatePost => Icons.lock_outline_rounded,
            ExtractionFailureKind.noPlaceFound => Icons.location_off_outlined,
            ExtractionFailureKind.invalidUrl => Icons.link_off_rounded,
            ExtractionFailureKind.failed => Icons.error_outline_rounded,
          },
          title: kind.title,
          description: kind.description,
          actionLabel: retryable ? '다시 시도' : '다른 링크 입력하기',
          onAction: retryable ? onRetry : () => context.go(AppRoutes.extract),
          secondaryLabel: retryable ? '다른 링크 입력하기' : null,
          onSecondary: () => context.go(AppRoutes.extract),
        ),
      ),
    );
  }
}

class _Review extends StatefulWidget {
  const _Review({required this.result});
  final ExtractionResult result;

  @override
  State<_Review> createState() => _ReviewState();
}

class _ReviewState extends State<_Review> {
  // 기본: 저장 가능한 장소 모두 선택
  late final Set<String> _selected = {
    for (final p in widget.result.places)
      if (!p.alreadySaved) p.place.id,
  };

  List<ExtractedPlace> get _selectable => widget.result.places.where((p) => !p.alreadySaved).toList();

  Future<void> _save() async {
    final places = [
      for (final p in widget.result.places)
        if (_selected.contains(p.place.id)) p.place,
    ];
    final ok = await showCollectionPickerSheet(context, places: places);
    if (ok != true || !mounted) return;
    // 저장 후 이동: 한 곳이면 장소 상세, 여러 곳이면 저장됨 (SCREEN_FLOW: saved_or_place_detail)
    context.go(places.length == 1 ? AppRoutes.place(places.single.id) : AppRoutes.saved);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final allSaved = _selectable.isEmpty;
    final allSelected = !allSaved && _selectable.every((p) => _selected.contains(p.place.id));

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xs, AppSpacing.screenH, AppSpacing.lg),
            children: [
              InfoCard(
                title: 'Instagram 링크 분석 완료',
                titleColor: AppColors.primary,
                description: allSaved ? '추출된 장소가 모두 이미 저장되어 있어요.' : '저장할 장소가 맞는지 확인해주세요.',
              ),
              SectionHeader(
                title: '추출된 장소',
                padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.sm),
                trailing: allSaved
                    ? null
                    : AppTextLink(
                        label: allSelected ? '선택 해제' : '모두 선택',
                        onPressed: () => setState(() {
                          allSelected ? _selected.clear() : _selected.addAll(_selectable.map((p) => p.place.id));
                        }),
                      ),
              ),
              for (final item in r.places)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ExtractedPlaceCard(
                    item: item,
                    selected: _selected.contains(item.place.id),
                    onTap: () => setState(() => _selected.contains(item.place.id)
                        ? _selected.remove(item.place.id)
                        : _selected.add(item.place.id)),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                onTap: () => openExternalLink(context, r.sourceUrl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('원본 게시물', style: AppTypography.meta.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                      '${r.sourceHandle == null ? '' : '${r.sourceHandle} · '}게시물 확인하기 ›',
                      style: AppTypography.bodyStrong.copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        BottomCta(
          caption: allSaved ? null : '다음 단계에서 보관함을 선택할 수 있어요.',
          child: allSaved
              ? AppButton(label: '저장됨에서 보기', variant: AppButtonVariant.soft, onPressed: () => context.go(AppRoutes.saved))
              : AppButton.dark(
                  label: '선택한 ${_selected.length}곳 저장하기',
                  onPressed: _selected.isEmpty ? null : _save,
                ),
        ),
      ],
    );
  }
}
