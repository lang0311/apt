import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/repositories.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/overlays.dart';
import '../../../../core/widgets/selection.dart';
import '../../../../core/widgets/states.dart';
import '../../../../core/widgets/surfaces.dart';
import '../../../place/domain/place.dart';
import '../saved_providers.dart';
import 'create_collection_modal.dart';

enum CollectionPickerMode {
  /// 추출 결과 저장: 장소들을 저장하고 선택한 보관함에 넣는다
  save,

  /// 장소 상세의 보관함 변경: 한 장소의 소속 보관함을 교체한다
  change,
}

/// #12 보관함 선택 바텀시트 (복수 선택). 저장에 성공하면 true.
/// "전체 저장 장소"는 기본 저장 위치라 항상 포함된다.
Future<bool?> showCollectionPickerSheet(
  BuildContext context, {
  required List<Place> places,
  CollectionPickerMode mode = CollectionPickerMode.save,
  Set<String> initialSelected = const {},
}) {
  return showAppBottomSheet<bool>(
    context,
    builder: (_) => _CollectionPicker(places: places, mode: mode, initialSelected: initialSelected),
  );
}

class _CollectionPicker extends ConsumerStatefulWidget {
  const _CollectionPicker({required this.places, required this.mode, required this.initialSelected});
  final List<Place> places;
  final CollectionPickerMode mode;
  final Set<String> initialSelected;

  @override
  ConsumerState<_CollectionPicker> createState() => _CollectionPickerState();
}

class _CollectionPickerState extends ConsumerState<_CollectionPicker> {
  late final Set<String> _selected = {...widget.initialSelected};
  bool _saving = false;

  Future<void> _create() async {
    final created = await showCreateCollectionModal(context);
    if (created != null) setState(() => _selected.add(created.id));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final repo = ref.read(savedRepositoryProvider);
    try {
      if (widget.mode == CollectionPickerMode.change) {
        await repo.setPlaceCollections(placeId: widget.places.single.id, collectionIds: _selected.toList());
      } else {
        await repo.savePlaces(placeIds: widget.places.map((p) => p.id).toList(), collectionIds: _selected.toList());
      }
      invalidateSavedData(ref);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showAppSnackBar(context, failureMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final collections = ref.watch(collectionsProvider);
    final summary = ref.watch(savedSummaryProvider);
    final first = widget.places.first;
    final count = 1 + _selected.length; // 전체 저장 장소 포함

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xs, AppSpacing.screenH, AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppNetworkImage(url: first.imageUrl, width: 44, height: 44, radius: 12),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  widget.places.length == 1 ? first.name : '${first.name} 외 ${widget.places.length - 1}곳',
                  style: AppTypography.bodyStrong,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(widget.mode == CollectionPickerMode.change ? '보관함 변경' : '보관함에 저장', style: AppTypography.title),
          const SizedBox(height: 4),
          Text('여러 보관함을 동시에 선택할 수 있어요.', style: AppTypography.meta),
          const SizedBox(height: AppSpacing.sm),
          Flexible(
            child: AsyncValueView(
              value: collections,
              compactError: true,
              loading: const SkeletonList(count: 3, padding: EdgeInsets.zero),
              onRetry: () => ref.invalidate(collectionsProvider),
              data: (list) => ListView(
                shrinkWrap: true,
                children: [
                  _Row(
                    title: '전체 저장 장소',
                    subtitle: summary.hasValue ? '${summary.value!.totalCount}곳' : null,
                    checked: true,
                    onTap: null,
                  ),
                  for (final c in list)
                    _Row(
                      title: c.name,
                      subtitle: '${c.placeCount}곳',
                      checked: _selected.contains(c.id),
                      onTap: () => setState(() => _selected.contains(c.id) ? _selected.remove(c.id) : _selected.add(c.id)),
                    ),
                  InkWell(
                    onTap: _create,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.xs),
                      child: Row(
                        children: [
                          const Icon(Icons.add_rounded, color: AppColors.primary),
                          const SizedBox(width: AppSpacing.sm),
                          Text('새 보관함 만들기', style: AppTypography.label.copyWith(color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: widget.mode == CollectionPickerMode.change ? '보관함 변경하기' : '$count개 보관함에 저장하기',
            loading: _saving,
            onPressed: collections.hasValue ? _save : null,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.title, this.subtitle, required this.checked, required this.onTap});
  final String title;
  final String? subtitle;
  final bool checked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: checked,
      enabled: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: [
              const IconCircle(icon: Icons.folder_outlined),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.bodyStrong),
                    if (subtitle != null) Text(subtitle!, style: AppTypography.caption),
                  ],
                ),
              ),
              Opacity(opacity: onTap == null ? 0.6 : 1, child: SquareCheck(checked: checked)),
            ],
          ),
        ),
      ),
    );
  }
}
