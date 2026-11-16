import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/models/geo_point.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/chips.dart';
import '../../../../core/widgets/inputs.dart';
import '../../../../core/widgets/map/apt_map.dart';
import '../../../../core/widgets/map/map_pin.dart';
import '../../../../core/widgets/overlays.dart';
import '../../../../core/widgets/states.dart';
import '../../domain/saved_models.dart';
import '../saved_providers.dart';
import '../widgets/category_style.dart';
import '../widgets/place_image.dart';
import '../widgets/place_list_tile.dart';
import '../widgets/saved_rows.dart';

/// #18 카테고리 기준 지도(저장 지도) / #19 보관함 기준 지도·목록
///
/// 저장 지도(07 D48): 위에는 흐림 검색창 + `필터` 칩(카테고리 여러 개), 지도에는 직접 저장한 곳과
/// 코스를 저장할 때 추천받아 저장된 곳(07 D44)의 핀. 아래 시트는 처음 높이에서 `이 지역 n곳` + `직접 저장` ·
/// `추천받은 곳` 칩 + 가로 카드 + 자동 검색 + `목록으로 보기`이고, 끌어올리면(검색창 아래까지) 세로 목록만 보인다.
/// 지도 이동 → debounce → 보이는 영역 안의 장소만 시트에 보인다.
/// 보관함 지도는 예전 모양 그대로다(서버 모드에는 보관함이 없다).
class SavedMapPage extends ConsumerStatefulWidget {
  const SavedMapPage({
    super.key,
    required this.mode,
    this.initialCategoryKeys = const {},
    this.aiOnly = false,
    this.initialCollectionId,
  });

  final SavedMapMode mode;
  final Set<String> initialCategoryKeys;

  /// 저장됨 AI 추천 탭에서 들어오면 추천받은 곳만 켜진 채로 연다
  final bool aiOnly;
  final String? initialCollectionId;

  @override
  ConsumerState<SavedMapPage> createState() => _SavedMapPageState();
}

class _SavedMapPageState extends ConsumerState<SavedMapPage> {
  late Set<String> _categories = widget.initialCategoryKeys;
  late bool _showMine = !widget.aiOnly;
  bool _showAi = true;
  late String? _collectionId = widget.initialCollectionId;
  String _keyword = '';
  String _listKeyword = '';
  SavedSort _sort = SavedSort.nearest;
  bool _autoSearch = true;
  GeoBounds? _bounds;
  final _map = AptMapController();
  String? _selectedId;
  Timer? _debounce;
  final _sheet = DraggableScrollableController();
  bool _cameraPlaced = false;
  bool _fitOnNextData = false;
  bool _expanded = false;
  List<GeoPoint> _markerPoints = const [];

  static const _empty = SavedSummary(totalCount: 0, categories: []);

  bool get _isCollection => widget.mode == SavedMapMode.collection;

  bool get _hasLocation => ref.read(myLocationProvider)?.point != null;

  /// 내 위치를 모르면 '가까운 순'을 쓸 수 없다 → 최근 순
  SavedSort get _effectiveSort => _sort == SavedSort.nearest && !_hasLocation ? SavedSort.recent : _sort;

  /// 보관함 지도의 조회 조건
  SavedPlaceQuery get _collectionQuery => SavedPlaceQuery(
        collectionId: _collectionId,
        keyword: _keyword.isEmpty ? null : _keyword,
        sort: _effectiveSort,
      );

  /// 저장 지도의 직접 저장 조회 조건 (카테고리는 받아 온 뒤 앱이 거른다 — 여러 개 고르기)
  SavedPlaceQuery get _mineQuery => SavedPlaceQuery(keyword: _keyword.isEmpty ? null : _keyword);

  @override
  void initState() {
    super.initState();
    Future.microtask(_locateOnEnter);
  }

  /// 지도에 들어오면 위치 권한을 묻는다. 거부해도 지도는 그대로 쓸 수 있고 거리·가까운 순만 빠진다.
  Future<void> _locateOnEnter() async {
    await ref.read(myLocationProvider.notifier).locate();
    if (!mounted) return;
    _map.showLocationDot(ref.read(myLocationProvider)?.point);
    _placeCamera();
  }

  /// 저장 지도의 첫 카메라 (한 번만). 내 위치를 알면 내 위치, 모르면 저장 장소가 몰린 곳.
  /// 저장 장소가 전국에 흩어져 있으면 전체 맞춤은 의미가 없어서 내 위치를 우선한다.
  /// 보관함 지도는 AptMap 기본 동작(보관함 장소에 맞춤)을 쓴다.
  void _placeCamera() {
    if (_isCollection || _cameraPlaced) return;
    final location = ref.read(myLocationProvider);
    if (location == null) return; // 아직 위치를 묻는 중
    final me = location.point;
    if (me != null) {
      _cameraPlaced = _map.moveTo(me, zoom: 14);
    } else if (_markerPoints.isNotEmpty) {
      _cameraPlaced = _map.fitTo(_markerPoints);
    }
  }

  /// 보관함을 바꾸면 그 보관함 장소에 다시 맞춘다. (AptMap은 viewport 기반 화면에서 첫 로드에만 맞춘다)
  void _selectCollection(String id) {
    setState(() {
      _collectionId = id;
      _bounds = null;
      _fitOnNextData = true;
    });
    // 이미 받아 둔 보관함이면 listen이 다시 불리지 않으므로 다음 프레임에 직접 맞춘다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitCollectionIfPending());
  }

  void _fitCollectionIfPending() {
    if (!mounted || !_fitOnNextData || !ref.read(savedPlacesProvider(_collectionQuery)).hasValue) return;
    _fitOnNextData = false;
    if (_markerPoints.isNotEmpty) _map.fitTo(_markerPoints);
  }

  Future<void> _goToMyLocation() async {
    final result = await ref.read(myLocationProvider.notifier).locate();
    if (!mounted) return;
    final me = ref.read(myLocationProvider)?.point;
    if (me == null) return _locationFailed(result.status);
    _map.showLocationDot(me);
    // 미리보기 지도(지도 키 없음·인증 실패)에서는 위치를 보여줄 수 없다.
    if (!_map.moveTo(me)) showAppSnackBar(context, '지도 연동 후 내 위치를 볼 수 있어요.');
  }

  void _locationFailed(LocationStatus status) {
    void openSettings() => ref.read(locationServiceProvider).openSettings(status);
    switch (status) {
      case LocationStatus.deniedForever:
        showAppSnackBar(context, '설정에서 위치 권한을 허용해주세요.', actionLabel: '설정 열기', onAction: openSettings);
      case LocationStatus.serviceOff:
        showAppSnackBar(context, '기기의 위치 서비스를 켜주세요.', actionLabel: '설정 열기', onAction: openSettings);
      case LocationStatus.denied:
        showAppSnackBar(context, '위치 권한을 허용하면 내 주변 장소를 볼 수 있어요.');
      case LocationStatus.granted || LocationStatus.unavailable:
        showAppSnackBar(context, '현재 위치를 확인하지 못했어요. 잠시 후 다시 시도해주세요.');
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _sheet.dispose();
    super.dispose();
  }

  void _onCameraIdle(GeoBounds bounds) {
    if (!_autoSearch) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _bounds = bounds);
    });
  }

  void _setAutoSearch(bool on) => setState(() {
        _autoSearch = on;
        if (!on) _bounds = null;
      });

  @override
  Widget build(BuildContext context) => _isCollection ? _buildCollection(context) : _buildSavedMap(context);

  // ───────────────────────── 저장 지도 (07 D48) ─────────────────────────

  /// 직접 저장 · 추천받은 곳을 켜 둔 쪽만, 검색어 · 카테고리로 거른다
  AsyncValue<({List<SavedPlaceItem> mine, List<SavedPlaceItem> ai})> _shown() {
    final mine = _showMine ? ref.watch(savedPlacesProvider(_mineQuery)) : const AsyncData(<SavedPlaceItem>[]);
    final ai = _showAi ? ref.watch(aiSavedPlacesProvider) : const AsyncData(<SavedPlaceItem>[]);
    for (final value in [mine, ai]) {
      if (value.hasError) return AsyncError(value.error!, value.stackTrace ?? StackTrace.empty);
    }
    if (!mine.hasValue || !ai.hasValue) return const AsyncLoading();
    return AsyncData((
      mine: [for (final i in mine.value!) if (matchesCategories(i.place, _categories)) i],
      ai: [
        for (final i in ai.value!)
          if (matchesCategories(i.place, _categories) && (_keyword.isEmpty || i.place.name.contains(_keyword))) i,
      ],
    ));
  }

  /// 필터 시트의 카테고리 · 개수: 둘 다 더한다 (켜고 끄기는 시트 안에서 바뀌므로)
  SavedSummary? _summary() {
    final mine = ref.watch(savedSummaryProvider).value;
    final ai = ref.watch(aiSavedSummaryProvider).value ?? _empty;
    return mine == null ? null : mergeSummaries(mine, ai);
  }

  /// 한쪽만 켰거나 둘 다 껐을 때 이름
  String? get _sourceLabel => switch ((_showMine, _showAi)) {
        (true, true) => null,
        (true, false) => '직접 저장만',
        (false, true) => '추천받은 곳만',
        (false, false) => '보여 줄 장소 없음',
      };

  /// 지도에 보이는 영역 안의 장소 + 내 위치에서 직선거리 (07 D36)
  List<SavedPlaceItem> _inView(List<SavedPlaceItem> items) {
    final me = ref.read(myLocationProvider)?.point;
    final bounds = _autoSearch ? _bounds : null;
    final visible = [
      for (final item in items)
        if (bounds == null || (item.place.location != null && bounds.contains(item.place.location!))) item,
    ];
    return withDistanceFrom(me, visible, SavedSort.recent);
  }

  void _retry() {
    ref.invalidate(savedPlacesProvider(_mineQuery));
    ref.invalidate(aiSavedPlacesProvider);
  }

  void _toggleSource({bool? mine, bool? ai}) => setState(() {
        _showMine = mine ?? _showMine;
        _showAi = ai ?? _showAi;
        _selectedId = null;
      });

  Future<void> _openFilter(SavedSummary? summary) async {
    if (summary == null) return;
    // 직접 저장 · 추천받은 곳, 자동 검색도 이 시트 안에서 바꾼다 (지도 아래 시트를 얇게, UI 리뷰 12)
    await showCategoryFilterSheet(
      context,
      summary: summary,
      selected: _categories,
      sources: (mine: _showMine, ai: _showAi),
      autoSearch: _autoSearch,
      onApply: (keys) => setState(() {
        _categories = keys;
        _selectedId = null;
      }),
      onApplySources: (mine, ai) => _toggleSource(mine: mine, ai: ai),
      onApplyAutoSearch: _setAutoSearch,
    );
  }

  void _moveSheet(double size) => _sheet.animateTo(size, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);

  Widget _buildSavedMap(BuildContext context) {
    // 위치를 얻거나 잃으면 거리 표시가 바뀐다
    ref.watch(myLocationProvider);
    ref.listen(savedPlacesProvider(_mineQuery), (_, next) {
      if (next.hasValue) _placeCamera();
    });

    final shown = _shown();
    final summary = _summary();
    final value = shown.value;
    final all = value == null ? const <SavedPlaceItem>[] : [...value.mine, ...value.ai];
    final aiIds = {for (final i in value?.ai ?? const <SavedPlaceItem>[]) i.place.id};
    final mineInView = _inView(value?.mine ?? const []);
    final aiInView = _inView(value?.ai ?? const []);
    final markers = [
      for (final item in all)
        if (item.place.location != null)
          MapMarker(
            id: item.place.id,
            point: item.place.location!,
            kind: MapPinKind.place,
            icon: CategoryStyle.of(item.place.categoryKey).icon,
            color: CategoryStyle.of(item.place.categoryKey).color,
            label: item.place.id == _selectedId ? item.place.name : null,
          ),
    ];
    _markerPoints = [for (final m in markers) m.point];
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        final height = constraints.maxHeight;
        // 위 검색창 + 필터 칩 영역. 시트는 이 아래까지만 올라온다
        final overlayHeight = topInset + AppSpacing.xs + 44 + AppSpacing.xs + 36 + AppSpacing.xs;
        // 지도 화면의 시트는 제목 줄 + 가로 카드 한 줄만 (자동 검색 · 칩은 필터 시트로)
        final sheetMin = (176 / height).clamp(0.18, 0.4);
        final sheetMax = (1 - overlayHeight / height).clamp(sheetMin + 0.1, 0.95);
        return Stack(
          children: [
            Positioned.fill(
              child: AptMap(
                markers: markers,
                selectedId: _selectedId,
                bottomPadding: height * sheetMin,
                topPadding: overlayHeight - topInset,
                onCameraIdle: _onCameraIdle,
                onMarkerTap: (m) => setState(() => _selectedId = m.id),
                controller: _map,
              ),
            ),
            // 목록일 때는 숨기기만 한다 — 빼면 Stack 자식 순서가 바뀌어 시트가 다시 만들어진다
            Positioned(
              right: AppSpacing.sm,
              bottom: height * sheetMin + AppSpacing.xs,
              child: Visibility(
                visible: !_expanded,
                child: _FrostedIconButton(icon: Icons.my_location_rounded, tooltip: '내 위치', onPressed: _goToMyLocation),
              ),
            ),
            // '목록으로 보기'는 지도 위 작은 버튼 (코스 만들기 3단계와 같은 자리)
            // 지도 왼쪽 아래의 NAVER 로고를 가리지 않게 로고 위에 둔다
            Positioned(
              left: AppSpacing.sm,
              bottom: height * sheetMin + AppSpacing.xs + 36,
              child: Visibility(
                visible: !_expanded,
                child: _ListPill(count: mineInView.length + aiInView.length, onPressed: () => _moveSheet(sheetMax)),
              ),
            ),
            NotificationListener<DraggableScrollableNotification>(
              key: const ValueKey('saved-map-sheet'),
              onNotification: (n) {
                final expanded = n.extent > (sheetMin + sheetMax) / 2;
                if (expanded != _expanded) setState(() => _expanded = expanded);
                return false;
              },
              child: DraggableScrollableSheet(
                controller: _sheet,
                initialChildSize: sheetMin,
                minChildSize: sheetMin,
                maxChildSize: sheetMax,
                snap: true,
                builder: (context, scroll) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    // 목록은 연회색 바탕에 흰 묶음 카드, 지도 화면은 밝은 바탕
                    color: _expanded ? AppColors.bg : AppColors.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
                    boxShadow: AppShadow.soft,
                  ),
                  child: _savedSheet(scroll, shown, mineInView, aiInView, aiIds, sheetMax),
                ),
              ),
            ),
            SafeArea(child: _savedTop(summary)),
            if (_expanded)
              Positioned(
                left: 0,
                right: 0,
                bottom: AppSpacing.md,
                child: Center(child: _MapFab(onPressed: () => _moveSheet(sheetMin))),
              ),
          ],
        );
      }),
    );
  }

  /// 위: 뒤로 + 흐림 검색창, 그 아래 `필터` 칩
  Widget _savedTop(SavedSummary? summary) {
    final label = categoryFilterLabel(summary, _categories);
    // 건 조건(켜고 끄기 · 카테고리)을 한 칩에 모은다
    final active = [?_sourceLabel, if (_categories.isNotEmpty) label];
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _FrostedIconButton(icon: Icons.arrow_back_ios_new_rounded, tooltip: '뒤로', onPressed: () => context.pop()),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _Frosted(
                  radius: 14,
                  child: AppSearchField(
                    hint: '저장된 장소 검색',
                    fillColor: Colors.transparent,
                    onChanged: (v) => setState(() => _keyword = v.trim()),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _FilterChip(
            label: active.isEmpty ? '필터' : active.join(', '),
            active: active.isNotEmpty,
            onTap: summary == null ? null : () => _openFilter(summary),
            onClear: () => setState(() {
              _categories = const {};
              _showMine = true;
              _showAi = true;
            }),
          ),
        ],
      ),
    );
  }

  Widget _savedSheet(
    ScrollController scroll,
    AsyncValue<({List<SavedPlaceItem> mine, List<SavedPlaceItem> ai})> shown,
    List<SavedPlaceItem> mine,
    List<SavedPlaceItem> ai,
    Set<String> aiIds,
    double sheetMax,
  ) {
    final count = mine.length + ai.length;
    return ListView(
      controller: scroll,
      padding: EdgeInsets.only(bottom: _expanded ? 88 : AppSpacing.md),
      children: [
        const Center(child: SheetHandle()),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 0, AppSpacing.sm, 0),
          child: Row(
            children: [
              Text('이 지역', style: AppTypography.cardTitle),
              const SizedBox(width: 6),
              Expanded(
                child: Text(shown.hasValue ? '$count곳' : '', style: AppTypography.label.copyWith(color: AppColors.textTertiary)),
              ),
              if (_sourceLabel != null) Text(_sourceLabel!, style: AppTypography.meta.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        if (_sheetState(shown, count) case final Widget state)
          state
        else if (_expanded) ...[
          if (mine.isNotEmpty) _PlaceGroup(title: ai.isEmpty ? null : '직접 저장', items: mine, recommended: false),
          if (ai.isNotEmpty) _PlaceGroup(title: mine.isEmpty ? null : '추천받은 곳', items: ai, recommended: true),
        ] else ...[
          SizedBox(
            height: 70 + AppSpacing.sm * 2,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
              itemCount: count,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (_, i) {
                final item = i < mine.length ? mine[i] : ai[i - mine.length];
                return _MapPlaceCard(
                  item: item,
                  recommended: aiIds.contains(item.place.id),
                  selected: item.place.id == _selectedId,
                  onTap: () => context.push(AppRoutes.place(item.place.id)),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  /// 로딩 · 오류 · 빈 상태면 그 위젯, 보여 줄 장소가 있으면 null
  Widget? _sheetState(AsyncValue<Object> shown, int count) {
    if (shown.hasError && !shown.hasValue) return AppErrorState(error: shown.error!, compact: true, onRetry: _retry);
    if (!shown.hasValue) return const AppLoading(padding: EdgeInsets.all(AppSpacing.lg));
    if (count > 0) return null;
    if (!_showMine && !_showAi) {
      return const AppEmptyState(
        compact: true,
        icon: Icons.visibility_off_outlined,
        title: '보여 줄 장소가 없어요',
        description: '직접 저장이나 추천받은 곳을 켜 보세요.',
      );
    }
    final anySaved = (ref.read(savedSummaryProvider).value?.totalCount ?? 0) + (ref.read(aiSavedSummaryProvider).value?.totalCount ?? 0) > 0;
    // 저장 0곳: 찾아서 저장하도록 안내 (07 D32)
    if (!anySaved) {
      return AppEmptyState(
        compact: true,
        icon: Icons.bookmark_border_rounded,
        title: '아직 저장한 곳이 없어요',
        description: '가고 싶은 곳을 찾아 저장하면 지도에 표시돼요.',
        actionLabel: '장소 찾기',
        onAction: () => context.push(AppRoutes.placeSearch),
      );
    }
    if (_markerPoints.isEmpty) {
      return AppEmptyState(
        compact: true,
        icon: Icons.search_off_rounded,
        title: '찾는 장소가 없어요',
        actionLabel: '필터 풀기',
        onAction: () => setState(() {
          _categories = const {};
          _showMine = true;
          _showAi = true;
        }),
      );
    }
    return AppEmptyState(
      compact: true,
      icon: Icons.location_off_outlined,
      title: '이 근처에 저장한 장소가 없어요',
      actionLabel: '저장한 장소 전체 보기',
      onAction: () => _map.fitTo(_markerPoints),
    );
  }

  // ───────────────────────── 보관함 지도 (예전 모양) ─────────────────────────

  Widget _buildCollection(BuildContext context) {
    // 보관함이 지정되지 않았으면 첫 보관함으로
    if (_collectionId == null) {
      final first = ref.watch(collectionsProvider).value?.firstOrNull;
      if (first != null) _collectionId = first.id;
    }

    // 위치를 얻거나 잃으면 정렬('가까운 순')과 거리 표시가 바뀐다
    ref.watch(myLocationProvider);
    ref.listen(savedPlacesProvider(_collectionQuery), (_, next) {
      if (!next.hasValue) return;
      // 마커(_markerPoints)는 다음 build에서 바뀌므로 그 뒤에 맞춘다.
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitCollectionIfPending());
    });

    final all = ref.watch(savedPlacesProvider(_collectionQuery));
    final me = ref.read(myLocationProvider)?.point;
    final visible = _autoSearch && _bounds != null
        ? ref.watch(savedPlacesInBoundsProvider(MapQuery(_bounds!, _collectionQuery)))
        : all.whenData((items) => withDistanceFrom(me, items, _collectionQuery.sort));
    final markers = [
      for (final item in all.value ?? const <SavedPlaceItem>[])
        if (item.place.location != null)
          MapMarker(
            id: item.place.id,
            point: item.place.location!,
            kind: MapPinKind.place,
            icon: CategoryStyle.of(item.place.categoryKey).icon,
            color: CategoryStyle.of(item.place.categoryKey).color,
            label: item.place.id == _selectedId ? item.place.name : null,
          ),
    ];
    _markerPoints = [for (final m in markers) m.point];

    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        const sheetMin = 0.45;
        return Stack(
          children: [
            Positioned.fill(
              child: AptMap(
                markers: markers,
                selectedId: _selectedId,
                bottomPadding: constraints.maxHeight * sheetMin,
                // 상단 검색바 + 기준 카드 + 칩 영역
                topPadding: MediaQuery.paddingOf(context).top + 170,
                onCameraIdle: _onCameraIdle,
                onMarkerTap: (m) => setState(() => _selectedId = m.id),
                controller: _map,
                fitMarkersOnLoad: true,
              ),
            ),
            SafeArea(child: _collectionTop()),
            Positioned(
              right: AppSpacing.md,
              bottom: constraints.maxHeight * sheetMin + AppSpacing.sm,
              child: AppIconBox(icon: Icons.my_location_rounded, size: 48, tooltip: '내 위치', onPressed: _goToMyLocation),
            ),
            DraggableScrollableSheet(
              controller: _sheet,
              initialChildSize: sheetMin,
              minChildSize: 0.2,
              maxChildSize: 0.92,
              snap: true,
              builder: (context, scroll) => DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
                  boxShadow: AppShadow.soft,
                ),
                child: _collectionSheet(scroll, visible),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _collectionTop() {
    final collections = ref.watch(collectionsProvider).value ?? const <PlaceCollection>[];
    final current = collections.where((c) => c.id == _collectionId).firstOrNull;
    final modeValue = current == null ? '' : '${current.name} · ${current.placeCount}곳';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, 0),
          child: Row(
            children: [
              AppIconBox(icon: Icons.chevron_left_rounded, size: 48, tooltip: '뒤로', onPressed: () => context.pop()),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.medium), boxShadow: AppShadow.soft),
                  child: AppSearchField(hint: '저장된 장소 검색', onChanged: (v) => setState(() => _keyword = v.trim())),
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xs),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.medium), boxShadow: AppShadow.soft),
          child: Row(
            children: [
              Text('내 보관함', style: AppTypography.label.copyWith(color: AppColors.textSecondary)),
              const Spacer(),
              Text(modeValue, style: AppTypography.label.copyWith(color: AppColors.primary)),
            ],
          ),
        ),
        SizedBox(
          height: AppSpacing.chipHeight + 4,
          child: ChipScroller(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            children: [
              for (final collection in collections)
                AppChip(
                  label: collection.name,
                  trailingCount: collection.placeCount,
                  selected: collection.id == _collectionId,
                  selectedColor: AppColors.ink,
                  onTap: () => _selectCollection(collection.id),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sheetHeader({required String title, required String subtitle, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xs, AppSpacing.screenH, AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.title),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTypography.meta),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _collectionSheet(ScrollController scroll, AsyncValue<List<SavedPlaceItem>> visible) {
    final collections = ref.watch(collectionsProvider).value ?? const <PlaceCollection>[];
    final current = collections.where((c) => c.id == _collectionId).firstOrNull;
    final list = (visible.value ?? const <SavedPlaceItem>[])
        .where((item) => _listKeyword.isEmpty || item.place.name.contains(_listKeyword))
        .toList();
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        const Center(child: SheetHandle()),
        _sheetHeader(
          title: current?.name ?? '내 보관함',
          subtitle: '보관함 ${current?.placeCount ?? 0}곳 중 지도에 보이는 ${visible.value?.length ?? 0}곳',
          trailing: AppButton(
            label: '${_effectiveSort.label} ▾',
            variant: AppButtonVariant.soft,
            expand: false,
            height: 40,
            onPressed: () => showActionSheet(context, title: '정렬', actions: [
              for (final sort in SavedSort.values)
                if (sort != SavedSort.nearest || _hasLocation)
                  SheetAction(
                    label: sort.label,
                    icon: sort == _effectiveSort ? Icons.check_rounded : Icons.sort_rounded,
                    onTap: () => setState(() => _sort = sort),
                  ),
            ]),
          ),
        ),
        Padding(
          padding: AppSpacing.screenPadding,
          child: AppSearchField(
            hint: '이 목록에서 장소 검색',
            fillColor: AppColors.bg,
            onChanged: (v) => setState(() => _listKeyword = v.trim()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.sm, AppSpacing.screenH, 0),
          child: Align(alignment: Alignment.centerLeft, child: _autoSearchToggle()),
        ),
        _visibleState(visible) ??
            (list.isEmpty
                ? const AppEmptyState(compact: true, icon: Icons.search_off_rounded, title: '이 영역에 저장한 장소가 없어요')
                : Column(
                    children: [
                      for (final item in list) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                          child: PlaceListTile(
                            place: item.place,
                            flat: true,
                            thumbSize: 72,
                            subtitle: [
                              item.place.categoryLabel,
                              if (item.place.rating != null) '★ ${item.place.rating!.toStringAsFixed(1)}',
                            ].join(' · '),
                            footer: _distanceText(item),
                            onTap: () => context.push(AppRoutes.place(item.place.id)),
                          ),
                        ),
                        const Divider(indent: AppSpacing.screenH, endIndent: AppSpacing.screenH),
                      ],
                    ],
                  )),
      ],
    );
  }

  /// 도보 20분 이내면 도보 시간, 아니면 거리. 둘 다 없으면 빈칸.
  Widget _distanceText(SavedPlaceItem item) {
    final label = _distanceLabel(item);
    if (label == null) return const SizedBox.shrink();
    return Text(label, style: AppTypography.label.copyWith(color: AppColors.primary));
  }

  /// 로딩/오류면 해당 위젯, 데이터가 있으면 null
  Widget? _visibleState(AsyncValue<List<SavedPlaceItem>> value) {
    if (value.hasError && !value.hasValue) {
      return AppErrorState(error: value.error!, compact: true, onRetry: () => ref.invalidate(savedPlacesInBoundsProvider));
    }
    if (!value.hasValue) return const AppLoading(padding: EdgeInsets.all(AppSpacing.lg));
    return null;
  }

  Widget _autoSearchToggle() {
    return Material(
      color: AppColors.bg,
      borderRadius: AppRadius.pillAll,
      child: InkWell(
        borderRadius: AppRadius.pillAll,
        onTap: () => _setAutoSearch(!_autoSearch),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _autoSearch ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text('지도 이동 시 자동 검색', style: AppTypography.label),
            ],
          ),
        ),
      ),
    );
  }
}

/// 도보 20분 이내면 도보 시간, 아니면 직선거리. 둘 다 없으면 null
String? _distanceLabel(SavedPlaceItem item) {
  if (item.walkMinutes != null && item.walkMinutes! <= 20) return '도보 ${item.walkMinutes}분';
  if (item.distanceMeters != null) return formatDistance(item.distanceMeters!);
  return null;
}

/// 지도 위 흐림 반투명 바탕 (코스 만들기 3/4 지도와 같은 모양)
class _Frosted extends StatelessWidget {
  const _Frosted({required this.child, this.radius = 14});
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: r, boxShadow: AppShadow.soft),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.mapGlass,
              borderRadius: r,
              border: Border.all(color: AppColors.mapGlassBorder),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _FrostedIconButton extends StatelessWidget {
  const _FrostedIconButton({required this.icon, required this.tooltip, required this.onPressed});
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _Frosted(
      radius: 13,
      child: SizedBox.square(
        dimension: 44,
        child: IconButton(tooltip: tooltip, onPressed: onPressed, icon: Icon(icon, size: 20, color: AppColors.textPrimary)),
      ),
    );
  }
}

/// `필터` 칩. 고르면 `한식` / `한식 외 1`로 바뀌고 파란 테두리, ×로 푼다 (07 D48)
class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.active, required this.onTap, required this.onClear});
  final String label;
  final bool active;
  final VoidCallback? onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.textPrimary;
    return Material(
      color: AppColors.mapPill,
      elevation: 1,
      shadowColor: AppColors.shadowFloat,
      shape: StadiumBorder(side: BorderSide(color: active ? AppColors.primary : AppColors.border)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            label: active ? '카테고리 필터, $label 적용됨' : '카테고리 필터',
            excludeSemantics: true,
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 36),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(10, 0, active ? 4 : 12, 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded, size: 16, color: color),
                      const SizedBox(width: 4),
                      Text(label, style: AppTypography.label.copyWith(color: color)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (active)
            Semantics(
              button: true,
              label: '카테고리 필터 해제',
              excludeSemantics: true,
              child: InkResponse(
                onTap: onClear,
                radius: 18,
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(2, 8, 10, 8),
                  child: Icon(Icons.close_rounded, size: 16, color: AppColors.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 지도 위 '목록 n' 버튼 (흰 알약)
class _ListPill extends StatelessWidget {
  const _ListPill({required this.count, required this.onPressed});
  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.mapPill,
      shape: const StadiumBorder(),
      elevation: 2,
      shadowColor: AppColors.shadowFloat,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: count == 0 ? null : onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.format_list_bulleted_rounded, size: 17, color: AppColors.textPrimary),
                const SizedBox(width: 5),
                Text('목록 $count', style: AppTypography.label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 목록에서 지도로 돌아가는 검정 버튼
class _MapFab extends StatelessWidget {
  const _MapFab({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.ink,
      shape: const StadiumBorder(),
      elevation: 3,
      shadowColor: AppColors.shadowStrong,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.map_outlined, size: 18, color: Colors.white),
                const SizedBox(width: 6),
                Text('지도', style: AppTypography.label.copyWith(color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 지도 아래 가로 카드 (높이 70, 코스 만들기 3/4 지도와 같은 모양). 사진이 없으면 카테고리 색 칸
class _MapPlaceCard extends StatelessWidget {
  const _MapPlaceCard({required this.item, required this.recommended, required this.selected, required this.onTap});
  final SavedPlaceItem item;
  final bool recommended;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final place = item.place;
    final distance = _distanceLabel(item);
    final radius = BorderRadius.circular(AppRadius.medium);
    return SizedBox(
      width: 240,
      child: Material(
        color: AppColors.surfaceRaised,
        elevation: 2,
        shadowColor: AppColors.shadowFloat,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: selected ? AppColors.primary : Colors.transparent, width: 1.5),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
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
                      Text(
                        [place.categoryLabel, ?distance].join(' · '),
                        style: AppTypography.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (recommended) _RecommendedLine(item),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 목록의 한 묶음: 카드 밖 작은 회색 제목(`직접 저장 5`) + 흰 카드 안의 행들 (07 D48)
class _PlaceGroup extends StatelessWidget {
  const _PlaceGroup({required this.title, required this.items, required this.recommended});

  /// 한쪽만 보일 때는 null (묶음 제목 없이)
  final String? title;
  final List<SavedPlaceItem> items;
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, AppSpacing.sm, 6, 6),
            child: title == null
                ? const SizedBox.shrink()
                : Text.rich(
                    TextSpan(children: [
                      TextSpan(text: '$title '),
                      TextSpan(text: '${items.length}', style: const TextStyle(color: AppColors.textTertiary, fontWeight: FontWeight.w700)),
                    ]),
                    style: AppTypography.meta.copyWith(fontWeight: FontWeight.w700),
                  ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(color: AppColors.surfaceRaised, borderRadius: BorderRadius.circular(AppRadius.medium)),
            child: Column(
              children: [
                for (final (i, item) in items.indexed) _PlaceRow(item: item, recommended: recommended, divider: i > 0),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.item, required this.recommended, required this.divider});
  final SavedPlaceItem item;
  final bool recommended;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final place = item.place;
    final distance = _distanceLabel(item);
    final sub = [if (place.shortArea.isNotEmpty) place.shortArea, place.categoryLabel].join(' · ');
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.medium),
      onTap: () => context.push(AppRoutes.place(place.id)),
      child: Stack(
        children: [
          // 구분선은 글자 시작부터
          if (divider) const Positioned(left: 64, right: 14, top: 0, child: Divider(height: 1, thickness: 1, color: AppColors.divider)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PlaceImage(place: place, width: 40, height: 40, radius: 11, iconSize: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(place.name, style: AppTypography.bodyStrong.copyWith(fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 1),
                      Text(sub, style: AppTypography.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (recommended) ...[const SizedBox(height: 2), _RecommendedLine(item)],
                    ],
                  ),
                ),
                if (distance != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(distance, style: AppTypography.caption.copyWith(color: AppColors.textTertiary, fontWeight: FontWeight.w700)),
                  ),
                ],
              ],
            ),
          ),
        ],
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
