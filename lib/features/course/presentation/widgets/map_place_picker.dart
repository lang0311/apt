import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/models/geo_point.dart';
import '../../../../core/widgets/map/apt_map.dart';
import '../../../../core/widgets/map/map_pin.dart';
import '../../../../core/widgets/states.dart';
import '../../../place/domain/place.dart';
import '../../../saved/domain/saved_models.dart';
import '../../../saved/presentation/saved_providers.dart';
import '../../../saved/presentation/widgets/category_style.dart';
import '../../../saved/presentation/widgets/place_image.dart';
import '../../../saved/presentation/widgets/saved_rows.dart';

/// 저장한 장소를 지도 위에서 고르는 화면 본문 (만들기 3단계 · 장소 추가가 같이 쓴다).
/// 지도를 깔고 위에 반투명 검색창(+ 필터 버튼), 아래에 장소 카드 한 줄. "목록"을 누르면 지역 묶음 목록이
/// 아래에서 올라오고, 끌어내리면 다시 지도가 보인다. 선택 상태는 호출 측이 가진다.
/// 카드 · 목록 · '목록 n'은 지금 지도에 보이는 영역 안의 장소만 (검색어가 있으면 영역과 상관없이 전체에서 찾는다).
/// 고른 순서는 추천에 쓰이지 않는다 — 서버는 고른 곳을 꼭 넣을 곳으로만 쓰고 방문 순서는 AI가 정한다.
class MapPlacePicker extends ConsumerStatefulWidget {
  const MapPlacePicker({
    super.key,
    required this.selectedIds,
    required this.onToggle,
    this.excludedIds = const {},
    this.excludedLabel = '코스에 있음',
    this.initialRegion,
  });

  /// 처음부터 걸어 둘 지역(구 · 시). 지역 묶음에서 코스 만들기로 들어올 때. 칩으로 풀 수 있다
  final String? initialRegion;

  final List<String> selectedIds;
  final ValueChanged<Place> onToggle;

  /// 이미 코스(보관함)에 있는 장소 — 흐리게 + [excludedLabel], 고를 수 없다
  final Set<String> excludedIds;
  final String excludedLabel;

  @override
  ConsumerState<MapPlacePicker> createState() => _MapPlacePickerState();
}

/// 장소 고르기에 보이는 장소: 직접 저장한 곳 + 코스를 저장할 때 추천받아 저장된 곳 (07 D47)
class _Pickable {
  const _Pickable({required this.mine, required this.ai});
  final List<SavedPlaceItem> mine;
  final List<SavedPlaceItem> ai;
  List<SavedPlaceItem> get all => [...mine, ...ai];
}

class _MapPlacePickerState extends ConsumerState<MapPlacePicker> {
  final _map = AptMapController();
  final _pages = PageController(viewportFraction: 0.64);
  /// 고른 카테고리(여러 개, 비면 전체, 07 D48)
  Set<String> _categories = const {};
  String _keyword = '';
  bool _listMode = false;
  String? _focusedId;

  /// 직접 저장 · 추천받은 곳 켜고 끄기. 필터 시트 안에서 바꾼다. 기본은 둘 다 켜짐, 화면을 나가면 기본으로 (07 D47)
  bool _showMine = true;
  bool _showAi = true;

  /// 지역 필터 (구 · 시). null이면 전체
  late String? _region = widget.initialRegion;

  /// 지금 지도에 보이는 영역. 지도가 처음 자리를 잡기 전(null)에는 전체
  GeoBounds? _bounds;
  Timer? _debounce;

  /// 카드를 넘기거나 핀을 눌러 지도가 움직인 경우에는 영역을 다시 잡지 않는다 (넘기는 중에 카드 줄이 바뀌지 않게)
  DateTime? _cameraByCardUntil;

  static const _searchHeight = 44.0;
  static const _cardHeight = 70.0;
  static const _empty = SavedSummary(totalCount: 0, categories: []);

  bool _matches(Place p) =>
      matchesCategories(p, _categories) && (_keyword.isEmpty || p.name.contains(_keyword));

  /// 직접 저장한 곳은 저장소가 검색어로 거른 결과, 추천받은 곳은 받아 둔 목록을 검색어로 거르고, 둘 다 카테고리로 거른다
  AsyncValue<_Pickable> _pickable() {
    final mine = _showMine ? ref.watch(savedPlacesProvider(_query)) : const AsyncData(<SavedPlaceItem>[]);
    final ai = _showAi ? ref.watch(aiSavedPlacesProvider) : const AsyncData(<SavedPlaceItem>[]);
    for (final value in [mine, ai]) {
      if (value.hasError) return AsyncError(value.error!, value.stackTrace ?? StackTrace.empty);
    }
    if (!mine.hasValue || !ai.hasValue) return const AsyncLoading();
    bool inRegion(Place p) => _region == null || p.district == _region;
    return AsyncData(_Pickable(
      mine: [for (final i in mine.value!) if (matchesCategories(i.place, _categories) && inRegion(i.place)) i],
      ai: [for (final i in ai.value!) if (_matches(i.place) && inRegion(i.place)) i],
    ));
  }

  /// 필터 시트의 카테고리 · 개수: 둘 다 더한다 (켜고 끄기는 시트 안에서 바뀌므로)
  SavedSummary? _summary() {
    final mine = ref.watch(savedSummaryProvider).value;
    final ai = ref.watch(aiSavedSummaryProvider).value ?? _empty;
    return mine == null ? null : mergeSummaries(mine, ai);
  }

  void _retry() {
    ref.invalidate(savedPlacesProvider(_query));
    ref.invalidate(aiSavedPlacesProvider);
  }

  SavedPlaceQuery get _query => SavedPlaceQuery(keyword: _keyword.isEmpty ? null : _keyword);

  void _onCameraIdle(GeoBounds bounds) {
    final until = _cameraByCardUntil;
    if (until != null && DateTime.now().isBefore(until)) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted || bounds == _bounds) return;
      setState(() {
        _bounds = bounds;
        _focusedId = null;
      });
      if (_pages.hasClients) _pages.jumpToPage(0);
    });
  }

  /// 위치가 없는 장소는 지도로 거를 수 없으니 늘 보인다
  bool _inView(Place p) =>
      _keyword.isNotEmpty || _bounds == null || p.location == null || _bounds!.contains(p.location!);

  @override
  void dispose() {
    _debounce?.cancel();
    _pages.dispose();
    super.dispose();
  }

  void _focus(List<Place> places, int index, {bool scrollCards = false}) {
    final p = places[index];
    setState(() => _focusedId = p.id);
    if (p.location != null && _map.moveTo(p.location!, zoom: 15)) {
      _cameraByCardUntil = DateTime.now().add(const Duration(milliseconds: 1500));
    }
    if (scrollCards && _pages.hasClients) {
      _pages.animateToPage(index, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
    }
  }

  /// 고른 장소는 파란 체크 핀(고른 순서는 추천에 쓰이지 않아 번호를 붙이지 않는다), 아니면 카테고리 아이콘 핀
  MapMarker _marker(Place place) {
    if (widget.selectedIds.contains(place.id)) {
      return MapMarker(id: place.id, point: place.location!, kind: MapPinKind.picked);
    }
    return MapMarker(
      id: place.id,
      point: place.location!,
      kind: MapPinKind.place,
      icon: CategoryStyle.of(place.categoryKey).icon,
      color: AppColors.primary,
    );
  }

  Future<void> _openFilter(SavedSummary? summary) async {
    if (summary == null) return;
    await showCategoryFilterSheet(
      context,
      summary: summary,
      selected: _categories,
      sources: (mine: _showMine, ai: _showAi),
      onApply: (keys) => setState(() {
        _categories = keys;
        _focusedId = null;
      }),
      onApplySources: (mine, ai) => setState(() {
        _showMine = mine;
        _showAi = ai;
        _focusedId = null;
      }),
    );
  }

  /// 한쪽만 켰거나 둘 다 껐을 때 칩 이름
  String? get _sourceLabel => switch ((_showMine, _showAi)) {
        (true, true) => null,
        (true, false) => '직접 저장만',
        (false, true) => '추천받은 곳만',
        (false, false) => '보여 줄 장소 없음',
      };

  @override
  Widget build(BuildContext context) {
    final filtered = _pickable();
    final summary = _summary();
    // 지도 핀은 거른 장소 전부(지도를 옮기면 보이게), 카드 · 목록은 지금 보이는 영역 안만
    final mapPlaces = [for (final i in filtered.value?.all ?? const <SavedPlaceItem>[]) i.place];
    final items = switch (filtered) {
      AsyncData(:final value) => AsyncData(_Pickable(
          mine: [for (final i in value.mine) if (_inView(i.place)) i],
          ai: [for (final i in value.ai) if (_inView(i.place)) i],
        )),
      _ => filtered,
    };
    final pickable = items.value;
    final all = pickable?.all ?? const <SavedPlaceItem>[];
    final places = [for (final i in all) i.place];
    final fromAi = {for (final i in pickable?.ai ?? const <SavedPlaceItem>[]) i.place.id: i};
    final noneShown = !_showMine && !_showAi;
    final selected = widget.selectedIds;
    final categoryLabel = _categories.isEmpty ? null : categoryFilterLabel(summary, _categories);
    final sourceLabel = _sourceLabel;
    final filterCount = _categories.length + (sourceLabel == null ? 0 : 1);
    final filterTop = _searchHeight + AppSpacing.xs * 2;
    // 건 필터 칩이 있으면 그 아래부터 지도·목록을 쓴다
    final hasChips = categoryLabel != null || sourceLabel != null || _region != null;
    final contentTop = filterTop + (hasChips ? 40 : 0);

    return Stack(
      children: [
        Positioned.fill(
          child: AptMap(
            controller: _map,
            topPadding: contentTop,
            bottomPadding: _cardHeight + 60,
            selectedId: _focusedId,
            onCameraIdle: _onCameraIdle,
            markers: [
              for (final p in mapPlaces)
                if (p.location != null && !widget.excludedIds.contains(p.id)) _marker(p),
            ],
            onMarkerTap: (m) {
              final i = places.indexWhere((p) => p.id == m.id);
              if (i >= 0) {
                _focus(places, i, scrollCards: true);
              } else {
                // 영역 가장자리라 아직 카드에 없던 핀: 그 핀으로 지도를 옮기면 영역이 다시 잡힌다
                final p = mapPlaces.where((p) => p.id == m.id).firstOrNull;
                if (p?.location != null) _map.moveTo(p!.location!, zoom: 15);
              }
            },
          ),
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
                  child: _Bubble(
                    text: noneShown
                        ? '필터에서 직접 저장이나 추천받은 곳을 켜 보세요'
                        : mapPlaces.isNotEmpty
                        ? '이 지역엔 저장한 곳이 없어요. 지도를 옮겨 보세요'
                        : _keyword.isEmpty && _categories.isEmpty
                        ? '저장한 장소가 없어요'
                        : '찾는 장소가 없어요',
                  ),
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
                      final place = places[i];
                      return Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xs),
                        child: _PlaceCard(
                          key: ValueKey(place.id),
                          place: place,
                          focused: place.id == _focusedId,
                          picked: selected.contains(place.id),
                          recommended: fromAi[place.id],
                          inCourse: widget.excludedIds.contains(place.id),
                          excludedLabel: widget.excludedLabel,
                          onTap: () => _focus(places, i, scrollCards: true),
                          onToggle: () => widget.onToggle(place),
                        ),
                      );
                    },
                  ),
                ),
              AsyncError() => Center(
                  child: _Bubble(text: '장소를 불러오지 못했어요', onTap: _retry),
                ),
              _ => const Center(child: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.4))),
            },
          ),
        ] else ...[
          // 목록: 아래에서 올라오는 시트. 끌어내리면 닫히고 지도가 보인다. 위쪽에 지도와 검색창이 남는다
          Positioned.fill(
            child: _ListSheet(
              top: contentTop + AppSpacing.xs,
              onClose: () => setState(() => _listMode = false),
              builder: (scroll) => _ListPanel(
                scroll: scroll,
                items: items,
                selectedIds: selected,
                excludedIds: widget.excludedIds,
                excludedLabel: widget.excludedLabel,
                onToggle: widget.onToggle,
                onRetry: _retry,
                noneShown: noneShown,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: AppSpacing.sm,
            child: Center(
              child: _MapPill(icon: Icons.map_outlined, label: '지도로 보기', dark: true, onTap: () => setState(() => _listMode = false)),
            ),
          ),
        ],

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
            filterCount: filterCount,
            onFilter: summary == null ? null : () => _openFilter(summary),
          ),
        ),
        // 건 필터만 칩으로 (안 걸면 줄이 없다)
        if (hasChips)
          Positioned(
            left: AppSpacing.sm,
            right: AppSpacing.sm,
            top: filterTop,
            child: Wrap(
              spacing: AppSpacing.xs,
              children: [
                if (_region != null) AppliedFilterChip(label: _region!, onClear: () => setState(() => _region = null)),
                if (sourceLabel != null)
                  AppliedFilterChip(
                    label: sourceLabel,
                    onClear: () => setState(() {
                      _showMine = true;
                      _showAi = true;
                    }),
                  ),
                if (categoryLabel != null) AppliedFilterChip(label: categoryLabel, onClear: () => setState(() => _categories = const {})),
              ],
            ),
          ),
      ],
    );
  }
}

/// 목록 시트: 열릴 때 아래에서 올라오고([top]까지), 손잡이나 목록 맨 위에서 끌어내리면 닫힌다.
class _ListSheet extends StatefulWidget {
  const _ListSheet({required this.top, required this.onClose, required this.builder});
  final double top;
  final VoidCallback onClose;
  final Widget Function(ScrollController scroll) builder;

  @override
  State<_ListSheet> createState() => _ListSheetState();
}

class _ListSheetState extends State<_ListSheet> {
  final _sheet = DraggableScrollableController();
  bool _closing = false;
  double _max = 0.9;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (!mounted || !_sheet.isAttached) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _sheet.jumpTo(_max);
    } else {
      await _sheet.animateTo(_max, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    }
  }

  bool _onExtent(DraggableScrollableNotification n) {
    // 열린 뒤에 다 내려가면 지도 상태로 돌아간다
    if (!_closing && _opened && n.extent <= 0.02) {
      _closing = true;
      widget.onClose();
    }
    if (n.extent >= _max - 0.01) _opened = true;
    return false;
  }

  bool _opened = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        _max = ((box.maxHeight - widget.top) / box.maxHeight).clamp(0.3, 1.0);
        return NotificationListener<DraggableScrollableNotification>(
          onNotification: _onExtent,
          child: DraggableScrollableSheet(
            controller: _sheet,
            initialChildSize: 0.02,
            minChildSize: 0,
            maxChildSize: _max,
            snap: true,
            builder: (context, scroll) => DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
                boxShadow: [BoxShadow(color: AppColors.shadowFloat, blurRadius: 16, offset: Offset(0, -4))],
              ),
              child: widget.builder(scroll),
            ),
          ),
        );
      },
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
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.small), boxShadow: AppShadow.soft),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.small),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: AppColors.mapGlass,
              borderRadius: BorderRadius.circular(AppRadius.small),
              border: Border.all(color: AppColors.mapGlassBorder),
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
                Container(width: 1, height: 22, color: AppColors.divider),
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
                          width: 17,
                          height: 17,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          child: Text('$filterCount', style: AppTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1)),
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
      color: dark ? AppColors.ink : AppColors.mapPill,
      shape: const StadiumBorder(),
      elevation: 2,
      shadowColor: AppColors.shadowFloat,
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
      borderRadius: BorderRadius.circular(AppRadius.medium),
      elevation: 2,
      shadowColor: AppColors.shadowFloat,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Text(onTap == null ? text : '$text · 다시 시도', style: AppTypography.meta.copyWith(color: AppColors.textPrimary)),
        ),
      ),
    );
  }
}

/// 고르기 원: 고른 장소는 파란 원 + 체크, 아니면 빈 원. 누르는 영역 44.
class _SelectButton extends StatelessWidget {
  const _SelectButton({required this.picked, required this.name, required this.onTap});
  final bool picked;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: picked,
      label: picked ? '$name 빼기' : '$name 고르기',
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: picked ? AppColors.primary : AppColors.surfaceRaised,
                border: picked ? null : Border.all(color: AppColors.controlBorder, width: 1.6),
              ),
              child: picked ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
            ),
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
      decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(AppRadius.tiny)),
      child: Text(label, style: AppTypography.caption.copyWith(fontWeight: FontWeight.w700)),
    );
  }
}

/// '성수동 · 카페' (동네 · 카테고리, 번지는 쓰지 않는다)
String _areaAndCategory(Place place) {
  final area = place.shortArea;
  return [if (area.isNotEmpty) area, place.categoryLabel].join(' · ');
}

/// 지도 아래 장소 카드 (높이 64, 사진 44). 카드를 누르면 지도가 그 장소로, 원을 누르면 고르기/빼기.
class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    super.key,
    required this.place,
    required this.focused,
    required this.picked,
    required this.inCourse,
    required this.excludedLabel,
    required this.onTap,
    required this.onToggle,
    this.recommended,
  });

  final Place place;
  final bool focused;
  final bool picked;

  /// 추천받아 저장된 곳이면 그 기록 (셋째 줄 "✦ ○○ 코스에서 추천")
  final SavedPlaceItem? recommended;
  final bool inCourse;
  final String excludedLabel;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.medium);
    return Opacity(
      opacity: inCourse ? 0.55 : 1,
      child: Material(
        color: AppColors.surfaceRaised,
        elevation: 3,
        shadowColor: AppColors.shadowFloat,
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
                PlaceImage(place: place, width: 44, height: 44, radius: 10, iconSize: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(place.name, style: AppTypography.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(_areaAndCategory(place), style: AppTypography.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (recommended != null) _RecommendedLine(recommended!),
                    ],
                  ),
                ),
                if (inCourse)
                  Padding(padding: const EdgeInsets.only(right: 10), child: _InCourseTag(excludedLabel))
                else
                  _SelectButton(picked: picked, name: place.name, onTap: onToggle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 목록 시트 안: 손잡이 · "저장한 장소 n" · 지역(구) 묶음. 추천받은 곳은 ✦ 한 줄로 구분한다
class _ListPanel extends StatelessWidget {
  const _ListPanel({
    required this.scroll,
    required this.items,
    required this.selectedIds,
    required this.excludedIds,
    required this.excludedLabel,
    required this.onToggle,
    required this.onRetry,
    required this.noneShown,
  });

  final ScrollController scroll;
  final AsyncValue<_Pickable> items;
  final List<String> selectedIds;
  final Set<String> excludedIds;
  final String excludedLabel;
  final ValueChanged<Place> onToggle;
  final VoidCallback onRetry;
  final bool noneShown;

  static const _noArea = '동네 정보 없음';

  /// 구 · 군 · 시로 묶고, 곳 수가 많은 묶음부터. 주소가 없는 곳은 맨 아래
  static List<(String, List<SavedPlaceItem>)> _groups(List<SavedPlaceItem> all) {
    final map = <String, List<SavedPlaceItem>>{};
    for (final i in all) {
      final d = i.place.district;
      map.putIfAbsent(d.isEmpty ? _noArea : d, () => []).add(i);
    }
    final groups = [for (final e in map.entries) (e.key, e.value)];
    groups.sort((a, b) {
      if (a.$1 == _noArea) return 1;
      if (b.$1 == _noArea) return -1;
      return b.$2.length.compareTo(a.$2.length);
    });
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final picked = items.value;
    final header = <Widget>[
      Center(
        child: Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.sm),
          decoration: BoxDecoration(color: AppColors.borderStrong, borderRadius: BorderRadius.circular(2)),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.xxs),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: '저장한 장소', style: AppTypography.cardTitle),
            if (picked != null) TextSpan(text: '  ${picked.all.length}', style: AppTypography.label.copyWith(color: AppColors.textTertiary)),
          ]),
        ),
      ),
    ];

    Widget message(Widget child) => ListView(controller: scroll, children: [...header, SizedBox(height: 220, child: child)]);

    if (picked == null) {
      return message(AsyncValueView<_Pickable>(value: items, onRetry: onRetry, data: (_) => const SizedBox.shrink()));
    }
    if (noneShown) {
      return message(const _ListMessage(title: '보여 줄 장소가 없어요', message: '필터에서 직접 저장이나 추천받은 곳을 켜 보세요.'));
    }
    if (picked.all.isEmpty) return message(const _ListMessage(title: '찾는 장소가 없어요', message: '지도를 옮기거나 검색해 보세요.'));

    final aiIds = {for (final i in picked.ai) i.place.id};
    final entries = <Object>[
      for (final (name, list) in _groups(picked.all)) ...[(name, list.length), ...list],
    ];
    return ListView.builder(
      controller: scroll,
      // 아래 '지도로 보기' 버튼에 가리지 않게
      padding: const EdgeInsets.only(bottom: 72),
      itemCount: header.length + entries.length,
      itemBuilder: (_, i) {
        if (i < header.length) return header[i];
        final entry = entries[i - header.length];
        if (entry is (String, int)) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, AppSpacing.xxs),
            child: Row(
              children: [
                Expanded(child: Text(entry.$1, style: AppTypography.label)),
                Text('${entry.$2}곳', style: AppTypography.meta),
              ],
            ),
          );
        }
        final item = entry as SavedPlaceItem;
        return _row(item, recommended: aiIds.contains(item.place.id));
      },
    );
  }

  Widget _row(SavedPlaceItem item, {required bool recommended}) {
    final p = item.place;
    final inCourse = excludedIds.contains(p.id);
    return Opacity(
      key: ValueKey(p.id),
      opacity: inCourse ? 0.55 : 1,
      child: InkWell(
        onTap: inCourse ? null : () => onToggle(p),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 6, AppSpacing.xs, 6),
          child: Row(
            children: [
              PlaceImage(place: p, width: 44, height: 44, radius: 12, iconSize: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: AppTypography.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(_areaAndCategory(p), style: AppTypography.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (recommended) _RecommendedLine(item),
                  ],
                ),
              ),
              if (inCourse)
                Padding(padding: const EdgeInsets.all(10), child: _InCourseTag(excludedLabel))
              else
                _SelectButton(picked: selectedIds.contains(p.id), name: p.name, onTap: () => onToggle(p)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListMessage extends StatelessWidget {
  const _ListMessage({required this.title, this.message});
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: AppTypography.bodyStrong, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 4),
              Text(message!, style: AppTypography.meta, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

/// "✦ ○○ 코스에서 추천" — 저장됨 AI 추천 탭과 같은 표시 (07 D44)
class _RecommendedLine extends StatelessWidget {
  const _RecommendedLine(this.item);
  final SavedPlaceItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.auto_awesome, size: 11, color: AppColors.ai),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            SavedPlaceRow.recommendedLabel(item.recommendedIn),
            style: AppTypography.caption.copyWith(color: AppColors.aiText, fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// 버튼 위 "고른 곳 n" + 이름 칩(× 로 빼기). 많으면 옆으로 넘긴다.
/// 순서 번호는 붙이지 않는다 (추천은 고른 곳을 꼭 넣을 곳으로만 쓰고 방문 순서는 AI가 정한다)
class PickedChips extends StatelessWidget {
  const PickedChips({super.key, required this.places, required this.onRemove});
  final List<Place> places;
  final ValueChanged<Place> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('고른 곳 ${places.length}', style: AppTypography.meta.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: places.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final p = places[i];
              return Semantics(
                button: true,
                label: '${p.name} 빼기',
                excludeSemantics: true,
                child: Material(
                  color: AppColors.surfaceRaised,
                  shape: const StadiumBorder(side: BorderSide(color: AppColors.border)),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => onRemove(p),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.xs, 0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 140),
                            child: Text(p.name, style: AppTypography.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.close_rounded, size: 15, color: AppColors.textTertiary),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
