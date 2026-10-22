import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/repositories.dart';
import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/utils/external_link.dart';
import '../../../../core/widgets/bottom_cta.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/headers.dart';
import '../../../../core/widgets/overlays.dart';
import '../../../../core/widgets/states.dart';
import '../../../../core/widgets/surfaces.dart';
import '../../../saved/presentation/saved_providers.dart';
import '../../../saved/presentation/widgets/collection_select_sheet.dart';
import '../../domain/extraction_models.dart';
import '../extraction_providers.dart';
import '../widgets/extracted_place_card.dart';

/// #11 찾은 장소. 공유로 들어오면 링크 입력(#10)을 건너뛰고 여기서 분석을 자동 시작한다.
/// 찾는 중 · 결과 · 실패 모두 맨 위 링크 줄은 그대로 두고 아래 카드만 바꾼다 (07 D26).
class ExtractionResultPage extends ConsumerWidget {
  const ExtractionResultPage({super.key, required this.url, this.fromShare = false});
  final String url;
  final bool fromShare;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(extractionProvider(url));
    final handle = result.value?.sourceHandle;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            PlainHeader(
              title: '찾은 장소',
              onLeading: () => context.canPop() ? context.pop() : context.go(AppRoutes.extract),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: _SourceRow(url: url, handle: handle),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: result.when(
                loading: () => const _Searching(),
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

/// 링크 줄: 계정 이름을 받으면 '@계정 · 릴스', 받기 전(찾는 중)이나 못 받으면 링크 그대로.
/// NEEDS BACKEND: 계정 이름은 추출 결과의 sourceHandle로만 받는다.
class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.url, this.handle});
  final String url;
  final String? handle;

  @override
  Widget build(BuildContext context) {
    final kind = url.contains('/reel') ? '릴스' : '게시물';
    final h = handle == null || handle!.isEmpty ? null : (handle!.startsWith('@') ? handle! : '@$handle');
    final shortUrl = url.replaceFirst(RegExp(r'^https?://(www\.)?'), '');
    return ExtractSourceRow(
      leading: h == null ? const LinkTile() : const InstagramTile(),
      action: SourceRowAction(label: '게시물 보기', onPressed: () => openExternalLink(context, url)),
      child: h == null
          ? Text(shortUrl, style: AppTypography.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis)
          : Text.rich(
              TextSpan(children: [
                TextSpan(text: h, style: AppTypography.bodyStrong.copyWith(fontWeight: FontWeight.w700)),
                TextSpan(text: ' · $kind', style: AppTypography.meta),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
    );
  }
}

class _Searching extends StatelessWidget {
  const _Searching();

  @override
  Widget build(BuildContext context) {
    Widget row() => const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
          child: Row(
            children: [
              SkeletonBox(width: 48, height: 48),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FractionallySizedBox(widthFactor: 0.55, child: SkeletonBox(height: 13, radius: 6)),
                    SizedBox(height: 7),
                    FractionallySizedBox(widthFactor: 0.35, child: SkeletonBox(height: 11, radius: 6)),
                  ],
                ),
              ),
            ],
          ),
        );
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      children: [
        Semantics(
          liveRegion: true,
          child: SectionCard(title: '장소를 찾고 있어요', child: Column(children: [row(), row()])),
        ),
      ],
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
    void toInput() => context.go(AppRoutes.extract);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.cardAll,
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Icon(
                        switch (kind) {
                          ExtractionFailureKind.privatePost => Icons.lock_outline_rounded,
                          ExtractionFailureKind.noPlaceFound => Icons.location_off_outlined,
                          ExtractionFailureKind.invalidUrl => Icons.link_off_rounded,
                          ExtractionFailureKind.failed => Icons.error_outline_rounded,
                        },
                        size: 17,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(kind.title, style: AppTypography.bodyStrong.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Text(kind.description, style: AppTypography.meta),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (retryable)
                Align(
                  alignment: Alignment.center,
                  child: AppTextLink(label: '다른 링크 넣기', onPressed: toInput),
                ),
            ],
          ),
        ),
        BottomCta(
          child: retryable
              ? AppButton(label: '다시 시도', onPressed: onRetry)
              : AppButton(label: '다른 링크 넣기', onPressed: toInput),
        ),
      ],
    );
  }
}

class _Review extends ConsumerStatefulWidget {
  const _Review({required this.result});
  final ExtractionResult result;

  @override
  ConsumerState<_Review> createState() => _ReviewState();
}

class _ReviewState extends ConsumerState<_Review> {
  // 기본: 저장 가능한 장소 모두 선택
  late final Set<String> _selected = {
    for (final p in widget.result.places)
      if (!p.alreadySaved) p.place.id,
  };

  /// 장소 id → 넣을 보관함 id (저장 전에 정해 두는 값)
  final Map<String, Set<String>> _collections = {};
  bool _saving = false;

  List<ExtractedPlace> get _selectable => widget.result.places.where((p) => !p.alreadySaved).toList();

  void _toggle(String id) => setState(() => _selected.contains(id) ? _selected.remove(id) : _selected.add(id));

  Future<void> _pickCollections(ExtractedPlace item) async {
    final id = item.place.id;
    final picked = await showCollectionSelectSheet(
      context,
      placeName: item.place.name,
      initialSelected: _collections[id] ?? const {},
      applyAllCount: {..._selected, id}.length,
    );
    if (picked == null || !mounted) return;
    setState(() {
      // 보관함을 고른 장소는 저장할 장소로 둔다
      _selected.add(id);
      final targets = picked.applyToAll ? _selected : {id};
      for (final t in targets) {
        _collections[t] = {...picked.collectionIds};
      }
    });
  }

  String? _label(String placeId, Map<String, String> names) {
    final ids = (_collections[placeId] ?? const <String>{}).where(names.containsKey).toList();
    if (ids.isEmpty) return null;
    final first = names[ids.first]!;
    return ids.length == 1 ? first : '$first 외 ${ids.length - 1}';
  }

  Future<void> _save() async {
    final places = [
      for (final p in widget.result.places)
        if (_selected.contains(p.place.id)) p.place,
    ];
    // 같은 보관함 조합끼리 묶어서 보낸다 (보관함 없음도 한 묶음).
    // NEEDS BACKEND: 장소별 보관함을 한 번에 받는 API가 있으면 한 번에, 일부만 실패했을 때 처리 방식 확인.
    final groups = <String, List<String>>{};
    final groupIds = <String, List<String>>{};
    for (final p in places) {
      final ids = (_collections[p.id] ?? const <String>{}).toList()..sort();
      final key = ids.join(',');
      groups.putIfAbsent(key, () => []).add(p.id);
      groupIds[key] = ids;
    }
    setState(() => _saving = true);
    final repo = ref.read(savedRepositoryProvider);
    try {
      for (final e in groups.entries) {
        await repo.savePlaces(placeIds: e.value, collectionIds: groupIds[e.key]!);
      }
      invalidateSavedData(ref);
      if (!mounted) return;
      // 저장 후 이동: 한 곳이면 장소 상세, 여러 곳이면 저장됨 (07 정해 주세요 ① 결정 전까지 지금 동작 유지)
      context.go(places.length == 1 ? AppRoutes.place(places.single.id) : AppRoutes.saved);
    } catch (e) {
      invalidateSavedData(ref);
      if (mounted) showAppSnackBar(context, failureMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final allSaved = _selectable.isEmpty;
    final allSelected = !allSaved && _selectable.every((p) => _selected.contains(p.place.id));
    final names = <String, String>{for (final c in ref.watch(collectionsProvider).value ?? []) c.id: c.name};

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.lg),
            children: [
              SectionCard(
                title: '찾은 장소 ${r.places.length}',
                trailing: allSaved
                    ? null
                    : AppTextLink(
                        label: allSelected ? '모두 해제' : '모두 선택',
                        onPressed: () => setState(() {
                          allSelected ? _selected.clear() : _selected.addAll(_selectable.map((p) => p.place.id));
                        }),
                      ),
                child: DividedRows(
                  indent: AppSpacing.md,
                  children: [
                    for (final item in r.places)
                      ExtractedPlaceRow(
                        item: item,
                        selected: _selected.contains(item.place.id),
                        collectionLabel: _label(item.place.id, names),
                        onToggle: () => _toggle(item.place.id),
                        onPickCollection: () => _pickCollections(item),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        BottomCta(
          child: allSaved
              ? AppButton(label: '저장됨에서 보기', variant: AppButtonVariant.soft, onPressed: () => context.go(AppRoutes.saved))
              : AppButton(
                  label: '${_selected.length}곳 저장',
                  loading: _saving,
                  onPressed: _selected.isEmpty ? null : _save,
                ),
        ),
      ],
    );
  }
}
