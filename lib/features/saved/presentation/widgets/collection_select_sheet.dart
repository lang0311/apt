import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/overlays.dart';
import '../../../../core/widgets/selection.dart';
import '../../../../core/widgets/states.dart';
import '../saved_providers.dart';
import 'create_collection_modal.dart';
import 'saved_rows.dart';

/// 보관함 고르기 결과. 저장은 하지 않고, 고른 보관함만 돌려준다.
class CollectionSelection {
  const CollectionSelection({required this.collectionIds, required this.applyToAll});
  final Set<String> collectionIds;

  /// 'n곳 모두 적용'을 켰는지
  final bool applyToAll;
}

/// 추출 결과에서 장소 한 곳의 보관함을 고르는 시트 (07 D26).
/// [applyAllCount]가 2 이상이면 맨 아래에 'n곳 모두 적용'을 보여 준다.
Future<CollectionSelection?> showCollectionSelectSheet(
  BuildContext context, {
  required String placeName,
  Set<String> initialSelected = const {},
  int applyAllCount = 0,
}) {
  return showAppBottomSheet<CollectionSelection>(
    context,
    builder: (_) => _CollectionSelect(placeName: placeName, initialSelected: initialSelected, applyAllCount: applyAllCount),
  );
}

class _CollectionSelect extends ConsumerStatefulWidget {
  const _CollectionSelect({required this.placeName, required this.initialSelected, required this.applyAllCount});
  final String placeName;
  final Set<String> initialSelected;
  final int applyAllCount;

  @override
  ConsumerState<_CollectionSelect> createState() => _CollectionSelectState();
}

class _CollectionSelectState extends ConsumerState<_CollectionSelect> {
  late final Set<String> _selected = {...widget.initialSelected};
  bool _applyAll = false;

  Future<void> _create() async {
    final created = await showCreateCollectionModal(context);
    if (created != null) setState(() => _selected.add(created.id));
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final collections = ref.watch(collectionsProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xs, AppSpacing.screenH, AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('보관함', style: AppTypography.title),
          const SizedBox(height: 2),
          Text(widget.placeName, style: AppTypography.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
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
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(AppRadius.sm)),
                      child: const Icon(Icons.add_rounded, color: AppColors.textSecondary),
                    ),
                    title: '새 보관함',
                    onTap: _create,
                  ),
                  for (final collection in list) ...[
                    const Divider(height: 1, thickness: 1, color: AppColors.divider),
                    _Row(
                      leading: MiniCollage(urls: collection.thumbnailUrls, size: 44),
                      title: collection.name,
                      subtitle: '${collection.placeCount}곳',
                      checked: _selected.contains(collection.id),
                      onTap: () => _toggle(collection.id),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (widget.applyAllCount > 1)
            Semantics(
              checked: _applyAll,
              child: InkWell(
                onTap: () => setState(() => _applyAll = !_applyAll),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    children: [
                      CheckMark(checked: _applyAll),
                      const SizedBox(width: AppSpacing.xs),
                      Text('${widget.applyAllCount}곳 모두 적용', style: AppTypography.bodyStrong.copyWith(fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          AppButton(
            label: '확인',
            onPressed: collections.hasValue
                ? () => Navigator.of(context).pop(CollectionSelection(collectionIds: {..._selected}, applyToAll: _applyAll))
                : null,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.leading, required this.title, this.subtitle, this.checked, required this.onTap});
  final Widget leading;
  final String title;
  final String? subtitle;

  /// null이면 체크 없는 행 (새 보관함)
  final bool? checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: checked == null,
      checked: checked,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              leading,
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (subtitle != null) Text(subtitle!, style: AppTypography.caption),
                  ],
                ),
              ),
              if (checked != null) CheckMark(checked: checked!),
            ],
          ),
        ),
      ),
    );
  }
}
