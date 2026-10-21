import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/map/apt_map.dart';
import '../../../../core/widgets/map/map_pin.dart';
import '../../../../core/widgets/selection.dart';
import '../../../../core/widgets/states.dart';
import '../../../place/domain/place.dart';
import '../../../saved/domain/saved_models.dart';
import '../../../saved/presentation/saved_providers.dart';
import '../../../saved/presentation/widgets/category_style.dart';
import '../../../saved/presentation/widgets/saved_rows.dart';

/// 저장한 장소를 지도 위에서 고르는 화면 본문 (만들기 3단계 · 장소 추가가 같이 쓴다).
/// 지도를 깔고 위에 반투명 검색창(+ 필터 버튼), 아래에 장소 카드 한 줄. "목록"으로 전체 목록을 덮어 본다.
/// 선택 상태는 호출 측이 가진다 ([selectedIds] 순서 = 고른 순서).
class MapPlacePicker extends ConsumerStatefulWidget {
  const MapPlacePicker({
    super.key,
    required this.selectedIds,
    required this.onToggle,
    this.excludedIds = const {},
    this.excludedLabel = '코스에 있음',
  });

  final List<String> selectedIds;
  final ValueChanged<Place> onToggle;

  /// 이미 코스(보관함)에 있는 장소 — 흐리게 + [excludedLabel], 고를 수 없다
  final Set<String> excludedIds;
  final String excludedLabel;

  @override
  ConsumerState<MapPlacePicker> createState() => _MapPlacePickerState();
}

class _MapPlacePickerState extends ConsumerState<MapPlacePicker> {
  final _map = AptMapController();
  final _pages = PageController(viewportFraction: 0.64);
  String? _categoryKey;
  String _keyword = '';
  bool _listMode = false;
  String? _focusedId;

  static const _searchHeight = 44.0;
  static const _cardHeight = 64.0;

  SavedPlaceQuery get _query => SavedPlaceQuery(categoryKey: _categoryKey, keyword: _keyword.isEmpty ? null : _keyword);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _focus(List<Place> places, int index, {bool scrollCards = false}) {
    final p = places[index];
    setState(() => _focusedId = p.id);
    if (p.location != null) _map.moveTo(p.location!, zoom: 15);
    if (scrollCards && _pages.hasClients) {
      _pages.animateToPage(index, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
    }
  }

  Future<void> _openFilter() async {
    final summary = ref.read(savedSummaryProvider).value;
    if (summary == null) return;
    final pick = await showCategoryFilterSheet(context, summary: summary, selectedKey: _categoryKey);
    if (pick != null) setState(() => _categoryKey = pick.key);
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(savedPlacesProvider(_query));
    final summary = ref.watch(savedSummaryProvider).value;
    final places = [for (final i in items.value ?? const <SavedPlaceItem>[]) i.place];
    final selected = widget.selectedIds;
    final categoryLabel = _categoryKey == null
        ? null
        : summary?.categories.where((c) => c.key == _categoryKey).firstOrNull?.label;
    final filterTop = _searchHeight + AppSpacing.xs * 2;

    return Stack(
      children: [
        Positioned.fill(
          child: AptMap(
            controller: _map,
            topPadding: filterTop + (categoryLabel == null ? 0 : 36),
            bottomPadding: _cardHeight + 60,
            selectedId: _focusedId,
            markers: [
              for (final p in places)
                if (p.location != null && !widget.excludedIds.contains(p.id))
                  selected.contains(p.id)
                      ? MapMarker(id: p.id, point: p.location!, kind: MapPinKind.numbered, number: selected.indexOf(p.id) + 1)
                      : MapMarker(
                          id: p.id,
                          point: p.location!,
                          kind: MapPinKind.place,
                          icon: CategoryStyle.of(p.categoryKey).icon,
                          color: AppColors.primary,
                        ),
            ],
            onMarkerTap: (m) {
              final i = places.indexWhere((p) => p.id == m.id);
              if (i >= 0) _focus(places, i, scrollCards: true);
            },
          ),
        ),

        // 목록 상태: 검색창 아래를 목록으로 덮는다
        if (_listMode)
          Positioned.fill(
            top: filterTop + (categoryLabel == null ? 0 : 36),
            child: _ListPanel(
              items: items,
              selectedIds: selected,
              excludedIds: widget.excludedIds,
              excludedLabel: widget.excludedLabel,
              onToggle: widget.onToggle,
              onRetry: () => ref.invalidate(savedPlacesProvider(_query)),
            ),
          ),

        // 반투명 검색창 + 필터 버튼
        Positioned(
          left: AppSpacing.sm,
          right: AppSpacing.sm,
          top: AppSpacing.xs,
          child: _SearchBar(
            height: _searchHeight,
            onChanged: (v) => setState(() {
              _keyword = v.trim();
              _focusedId = null;
            }),
            filterCount: _categoryKey == null ? 0 : 1,
            onFilter: summary == null ? null : _openFilter,
          ),
        ),
        // 건 필터만 칩으로 (안 걸면 줄이 없다)
        if (categoryLabel != null)
          Positioned(
            left: AppSpacing.sm,
            top: filterTop,
            child: AppliedFilterChip(label: categoryLabel, onClear: () => setState(() => _categoryKey = null)),
          ),

        if (!_listMode) ...[
          Positioned(
            left: AppSpacing.sm,
            bottom: _cardHeight + AppSpacing.lg,
            child: _MapPill(
              icon: Icons.format_list_bulleted_rounded,
              label: '목록 ${places.length}',
              onTap: () => setState(() => _listMode = true),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: AppSpacing.sm,
            height: _cardHeight,
            child: switch (items) {
              AsyncData() when places.isEmpty => Center(
                  child: _Bubble(text: _keyword.isEmpty && _categoryKey == null ? '저장한 장소가 없어요' : '찾는 장소가 없어요'),
                ),
              // 넘긴 카드가 늘 왼쪽 여백(12)에서 시작하도록 PageView를 여백 안에 두고, 지나간 카드는 밖으로 그린다
              AsyncData() => Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: PageView.builder(
                  clipBehavior: Clip.none,
                  controller: _pages,
                  padEnds: false,
                  itemCount: places.length,
                  onPageChanged: (i) => _focus(places, i),
                  itemBuilder: (_, i) {
                    final p = places[i];
                    return Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: _PlaceCard(
                        key: ValueKey(p.id),
                        place: p,
                        focused: p.id == _focusedId,
                        number: selected.contains(p.id) ? selected.indexOf(p.id) + 1 : null,
                        inCourse: widget.excludedIds.contains(p.id),
                        excludedLabel: widget.excludedLabel,
                        onTap: () => _focus(places, i, scrollCards: true),
                        onToggle: () => widget.onToggle(p),
                      ),
                    );
                  },
                ),
                ),
              AsyncError() => Center(
                  child: _Bubble(text: '장소를 불러오지 못했어요', onTap: () => ref.invalidate(savedPlacesProvider(_query))),
                ),
              _ => const Center(child: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.4))),
            },
          ),
        ] else
          Positioned(
            left: 0,
            right: 0,
            bottom: AppSpacing.sm,
            child: Center(
              child: _MapPill(icon: Icons.map_outlined, label: '지도', dark: true, onTap: () => setState(() => _listMode = false)),
            ),
          ),
      ],
    );
  }
}

/// 흰색 80% + 흐림 검색창. 오른쪽 필터 버튼(건 필터 수 배지).
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.height, required this.onChanged, required this.filterCount, this.onFilter});
  final double height;
  final ValueChanged<String> onChanged;
  final int filterCount;
  final VoidCallback? onFilter;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), boxShadow: AppShadow.soft),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
            ),
            child: Row(
              children: [
                const SizedBox(width: AppSpacing.sm),
                const Icon(Icons.search_rounded, size: 20, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: TextField(
                    onChanged: onChanged,
                    textInputAction: TextInputAction.search,
                    style: AppTypography.bodyStrong,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: '저장한 장소 검색',
                      hintStyle: AppTypography.bodyStrong.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                Container(width: 1, height: 22, color: AppColors.ink.withValues(alpha: 0.1)),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      tooltip: filterCount == 0 ? '필터' : '필터 $filterCount개 적용됨',
                      onPressed: onFilter,
                      icon: const Icon(Icons.tune_rounded, size: 20, color: AppColors.textPrimary),
                    ),
                    if (filterCount > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          width: 15,
                          height: 15,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          child: Text('$filterCount', style: AppTypography.caption.copyWith(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800, height: 1)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 지도 위 둥근 버튼 ("목록 12" / "지도")
class _MapPill extends StatelessWidget {
  const _MapPill({required this.icon, required this.label, required this.onTap, this.dark = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : AppColors.textPrimary;
    return Material(
      color: dark ? AppColors.ink : Colors.white.withValues(alpha: 0.92),
      shape: const StadiumBorder(),
      elevation: 2,
      shadowColor: const Color(0x2914223A),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: fg),
                const SizedBox(width: 5),
                Text(label, style: AppTypography.label.copyWith(color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, this.onTap});
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      shadowColor: const Color(0x2914223A),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Text(onTap == null ? text : '$text · 다시 시도', style: AppTypography.meta.copyWith(color: AppColors.textPrimary)),
        ),
      ),
    );
  }
}

/// 고르기 원: 고른 장소는 고른 순서 번호, 아니면 빈 원. 누르는 영역 48.
class _SelectButton extends StatelessWidget {
  const _SelectButton({required this.number, required this.name, required this.onTap});
  final int? number;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: number != null,
      label: number == null ? '$name 고르기' : '$name 빼기',
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: number == null
                ? Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceRaised,
                      border: Border.all(color: AppColors.controlBorder, width: 1.6),
                    ),
                  )
                : NumberBadge(number!, size: 24),
          ),
        ),
      ),
    );
  }
}

class _InCourseTag extends StatelessWidget {
  const _InCourseTag(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: AppTypography.caption.copyWith(fontSize: 10.5, fontWeight: FontWeight.w700)),
    );
  }
}

String _sub(Place p) {
  final parts = p.displayArea.trim().split(RegExp(r'\s+'));
  final area = parts.isEmpty ? '' : parts.last;
  return [if (area.isNotEmpty) area, p.categoryLabel].join(' · ');
}

/// 지도 아래 장소 카드 (높이 64, 사진 44). 카드를 누르면 지도가 그 장소로, 원을 누르면 고르기/빼기.
class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    super.key,
    required this.place,
    required this.focused,
    required this.number,
    required this.inCourse,
    required this.excludedLabel,
    required this.onTap,
    required this.onToggle,
  });

  final String excludedLabel;
  final Place place;
  final bool focused;
  final int? number;
  final bool inCourse;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return Opacity(
      opacity: inCourse ? 0.55 : 1,
      child: Material(
        color: AppColors.surfaceRaised,
        elevation: 3,
        shadowColor: const Color(0x2914223A),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: focused ? AppColors.primary : Colors.transparent, width: 1.5),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Row(
              children: [
                AppNetworkImage(url: place.imageUrl, width: 44, height: 44, radius: 10),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(place.name, style: AppTypography.bodyStrong.copyWith(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(_sub(place), style: AppTypography.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                if (inCourse)
                  Padding(padding: const EdgeInsets.only(right: 10), child: _InCourseTag(excludedLabel))
                else
                  _SelectButton(number: number, name: place.name, onTap: onToggle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 목록 상태: "저장한 장소 n · m곳 선택" + 행 목록
class _ListPanel extends StatelessWidget {
  const _ListPanel({
    required this.items,
    required this.selectedIds,
    required this.excludedIds,
    required this.excludedLabel,
    required this.onToggle,
    required this.onRetry,
  });

  final String excludedLabel;

  final AsyncValue<List<SavedPlaceItem>> items;
  final List<String> selectedIds;
  final Set<String> excludedIds;
  final ValueChanged<Place> onToggle;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: AsyncValueView<List<SavedPlaceItem>>(
        value: items,
        onRetry: onRetry,
        data: (list) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xxs),
              child: Row(
                children: [
                  Text('저장한 장소', style: AppTypography.cardTitle),
                  const SizedBox(width: 6),
                  Expanded(child: Text('${list.length}', style: AppTypography.label.copyWith(color: AppColors.textTertiary))),
                  Text('${selectedIds.length}곳 선택', style: AppTypography.meta),
                ],
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text('찾는 장소가 없어요'))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 72),
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final p = list[i].place;
                        final inCourse = excludedIds.contains(p.id);
                        final n = selectedIds.indexOf(p.id);
                        return Opacity(
                          key: ValueKey(p.id),
                          opacity: inCourse ? 0.55 : 1,
                          child: InkWell(
                            onTap: inCourse ? null : () => onToggle(p),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 6, AppSpacing.xs, 6),
                              child: Row(
                                children: [
                                  AppNetworkImage(url: p.imageUrl, width: 48, height: 48, radius: 12),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(p.name, style: AppTypography.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                                        Text(_sub(p), style: AppTypography.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                  if (inCourse)
                                    Padding(padding: const EdgeInsets.all(10), child: _InCourseTag(excludedLabel))
                                  else
                                    _SelectButton(number: n < 0 ? null : n + 1, name: p.name, onTap: () => onToggle(p)),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 하단 버튼 왼쪽 "고른 장소 사진 묶음 + n곳"
class PickedTray extends StatelessWidget {
  const PickedTray({super.key, required this.places});
  final List<Place> places;

  @override
  Widget build(BuildContext context) {
    final shown = places.take(3).toList();
    return Semantics(
      label: '${places.length}곳 고름',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: shown.isEmpty ? 0 : 30 + (shown.length - 1) * 20.0,
            height: 30,
            child: Stack(
              children: [
                for (var i = 0; i < shown.length; i++)
                  Positioned(
                    left: i * 20.0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(10)),
                      child: AppNetworkImage(url: shown[i].imageUrl, width: 26, height: 26, radius: 8),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text('${places.length}곳', style: AppTypography.label),
        ],
      ),
    );
  }
}
