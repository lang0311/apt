import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/chips.dart';
import '../../../../core/widgets/inputs.dart';
import '../../../../core/widgets/map/apt_map.dart';
import '../../../../core/widgets/map/map_pin.dart';
import '../../../../core/widgets/selection.dart';
import '../../../../core/widgets/states.dart';
import '../../../place/domain/place.dart';
import '../../domain/saved_models.dart';
import '../saved_providers.dart';
import 'category_style.dart';

enum PickerSelectionStyle {
  /// 선택 순서 번호 (코스 장소 선택 #24)
  numbered,

  /// 체크박스 (장소 추가 #29, 보관함에 추가)
  checkbox,
}

/// 저장한 장소 선택기: 검색 · 카테고리 칩 · 지도(선택 순서 핀) · 목록.
/// 선택 상태는 호출 측이 소유한다 ([selectedIds] 순서 = 선택 순서).
class SavedPlacePicker extends ConsumerStatefulWidget {
  const SavedPlacePicker({
    super.key,
    required this.selectedIds,
    required this.onToggle,
    this.style = PickerSelectionStyle.numbered,
    this.excludedIds = const {},
    this.showSavedTag = false,
  });

  final List<String> selectedIds;
  final ValueChanged<Place> onToggle;
  final PickerSelectionStyle style;

  /// 목록에서 숨길 장소 (이미 코스/보관함에 있는 장소)
  final Set<String> excludedIds;
  final bool showSavedTag;

  @override
  ConsumerState<SavedPlacePicker> createState() => _SavedPlacePickerState();
}

class _SavedPlacePickerState extends ConsumerState<SavedPlacePicker> {
  String? _categoryKey;
  String _keyword = '';

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(savedSummaryProvider);
    final query = SavedPlaceQuery(categoryKey: _categoryKey, keyword: _keyword.isEmpty ? null : _keyword);
    final places = ref.watch(savedPlacesProvider(query));
    final selected = widget.selectedIds;

    return Column(
      children: [
        Padding(
          padding: AppSpacing.screenPadding,
          child: AppSearchField(hint: '저장한 장소 검색', onChanged: (v) => setState(() => _keyword = v.trim())),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: AppSpacing.chipHeight + 4,
          child: ChipScroller(
            children: [
              AppChip(label: '전체', selected: _categoryKey == null, onTap: () => setState(() => _categoryKey = null)),
              for (final c in summary.value?.categories ?? const <PlaceCategory>[])
                AppChip(label: c.label, selected: _categoryKey == c.key, onTap: () => setState(() => _categoryKey = c.key)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: AsyncValueView<List<SavedPlaceItem>>(
            value: places,
            onRetry: () => ref.invalidate(savedPlacesProvider(query)),
            data: (all) {
              final list = all.where((i) => !widget.excludedIds.contains(i.place.id)).toList();
              return Column(
                children: [
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: AppSpacing.screenPadding,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        child: AptMap(
                          markers: [
                            for (final i in list)
                              if (i.place.location != null)
                                selected.contains(i.place.id)
                                    ? MapMarker(
                                        id: i.place.id,
                                        point: i.place.location!,
                                        kind: MapPinKind.numbered,
                                        number: selected.indexOf(i.place.id) + 1,
                                      )
                                    : MapMarker(
                                        id: i.place.id,
                                        point: i.place.location!,
                                        kind: MapPinKind.place,
                                        icon: CategoryStyle.of(i.place.categoryKey).icon,
                                        color: CategoryStyle.of(i.place.categoryKey).color,
                                      ),
                          ],
                          onMarkerTap: (m) => widget.onToggle(list.firstWhere((i) => i.place.id == m.id).place),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.sm, AppSpacing.screenH, 0),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
                            child: Row(
                              children: [
                                Expanded(child: Text('내가 저장한 장소', style: AppTypography.section)),
                                Text('${selected.length}곳 선택', style: AppTypography.label.copyWith(color: AppColors.primary)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: list.isEmpty
                                ? const AppEmptyState(
                                    compact: true,
                                    title: '선택할 수 있는 장소가 없어요',
                                    description: '다른 카테고리를 보거나 새 장소를 저장해보세요.',
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                                    itemCount: list.length,
                                    itemBuilder: (_, i) => _PickRow(
                                      place: list[i].place,
                                      order: selected.indexOf(list[i].place.id),
                                      style: widget.style,
                                      showSavedTag: widget.showSavedTag,
                                      onTap: () => widget.onToggle(list[i].place),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.place,
    required this.order,
    required this.style,
    required this.showSavedTag,
    required this.onTap,
  });

  final Place place;

  /// 선택 순서 (선택 안 됨 = -1)
  final int order;
  final PickerSelectionStyle style;
  final bool showSavedTag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = order >= 0;
    final origin = place.sourceUrl != null ? '인스타그램에서 저장' : place.displayArea;
    final hint = place.keywords.isEmpty ? place.categoryLabel : place.keywords.first;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: [
              AppNetworkImage(url: place.imageUrl, width: 56, height: 56, radius: 12),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(place.name, style: AppTypography.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('$origin · $hint', style: AppTypography.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (showSavedTag && place.isSaved) ...[
                      const SizedBox(height: 4),
                      const AppTag('저장됨', tone: AppTagTone.primary),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              switch (style) {
                PickerSelectionStyle.numbered => selected
                    ? NumberBadge(order + 1, size: 26)
                    : Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.border, width: 1.4)),
                      ),
                PickerSelectionStyle.checkbox => SquareCheck(checked: selected),
              },
            ],
          ),
        ),
      ),
    );
  }
}
