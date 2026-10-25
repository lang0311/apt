import 'dart:async';

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
import '../../../../core/widgets/app_network_image.dart';
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
import '../widgets/place_list_tile.dart';

/// #18 카테고리 기준 지도 / #19 보관함 기준 지도·목록
/// 지도 이동 → debounce → 보이는 영역을 덮는 원으로 nearby 조회 → 목록 갱신.
/// 카메라: 카테고리 지도는 내 위치에서 시작(모르면 저장 장소가 몰린 곳), 보관함 지도는 보관함 장소에 맞춘다.
class SavedMapPage extends ConsumerStatefulWidget {
  const SavedMapPage({super.key, required this.mode, this.initialCategoryKey, this.initialCollectionId});

  final SavedMapMode mode;
  final String? initialCategoryKey;
  final String? initialCollectionId;

  @override
  ConsumerState<SavedMapPage> createState() => _SavedMapPageState();
}

class _SavedMapPageState extends ConsumerState<SavedMapPage> {
  late String? _categoryKey = widget.initialCategoryKey;
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
  List<GeoPoint> _markerPoints = const [];

  bool get _isCollection => widget.mode == SavedMapMode.collection;

  bool get _hasLocation => ref.read(myLocationProvider)?.point != null;

  /// 내 위치를 모르면 '가까운 순'을 쓸 수 없다 → 최근 순
  SavedSort get _effectiveSort => _sort == SavedSort.nearest && !_hasLocation ? SavedSort.recent : _sort;

  SavedPlaceQuery get _query => SavedPlaceQuery(
        categoryKey: _isCollection ? null : _categoryKey,
        collectionId: _isCollection ? _collectionId : null,
        keyword: _keyword.isEmpty ? null : _keyword,
        sort: _isCollection ? _effectiveSort : SavedSort.recent,
      );

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

  /// 카테고리 지도의 첫 카메라 (한 번만). 내 위치를 알면 내 위치, 모르면 저장 장소가 몰린 곳.
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
    if (!mounted || !_fitOnNextData || !ref.read(savedPlacesProvider(_query)).hasValue) return;
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

  void _onCameraIdle(GeoBounds b) {
    if (!_autoSearch) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _bounds = b);
    });
  }

  @override
  Widget build(BuildContext context) {
    // 보관함 지도인데 보관함이 지정되지 않았으면 첫 보관함으로
    if (_isCollection && _collectionId == null) {
      final first = ref.watch(collectionsProvider).value?.firstOrNull;
      if (first != null) _collectionId = first.id;
    }

    // 위치를 얻거나 잃으면 정렬('가까운 순')과 거리 표시가 바뀐다
    ref.watch(myLocationProvider);
    ref.listen(savedPlacesProvider(_query), (_, next) {
      if (!next.hasValue) return;
      _placeCamera();
      // 마커(_markerPoints)는 다음 build에서 바뀌므로 그 뒤에 맞춘다.
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitCollectionIfPending());
    });

    final all = ref.watch(savedPlacesProvider(_query));
    final visible =_autoSearch && _bounds != null ? ref.watch(savedPlacesInBoundsProvider(MapQuery(_bounds!, _query))) : all;
    final markers = [
      for (final i in all.value ?? const <SavedPlaceItem>[])
        if (i.place.location != null)
          MapMarker(
            id: i.place.id,
            point: i.place.location!,
            kind: MapPinKind.place,
            icon: CategoryStyle.of(i.place.categoryKey).icon,
            color: CategoryStyle.of(i.place.categoryKey).color,
            label: i.place.id == _selectedId ? i.place.name : null,
          ),
    ];
    _markerPoints = [for (final m in markers) m.point];

    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        final sheetMin = _isCollection ? 0.45 : 0.36;
        return Stack(
          children: [
            Positioned.fill(
              child: AptMap(
                markers: markers,
                selectedId: _selectedId,
                bottomPadding: c.maxHeight * sheetMin,
                // 상단 검색바 + 기준 카드 + 칩 영역
                topPadding: MediaQuery.paddingOf(context).top + 170,
                onCameraIdle: _onCameraIdle,
                onMarkerTap: (m) => setState(() => _selectedId = m.id),
                controller: _map,
                fitMarkersOnLoad: _isCollection,
              ),
            ),
            SafeArea(child: _topOverlay()),
            Positioned(
              right: AppSpacing.md,
              bottom: c.maxHeight * sheetMin + AppSpacing.sm,
              child: AppIconBox(
                icon: Icons.my_location_rounded,
                size: 48,
                tooltip: '내 위치',
                onPressed: _goToMyLocation,
              ),
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
                child: _isCollection ? _collectionSheet(scroll, visible) : _categorySheet(scroll, visible),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _topOverlay() {
    final summary = ref.watch(savedSummaryProvider).value;
    final collections = ref.watch(collectionsProvider).value ?? const <PlaceCollection>[];
    final current = collections.where((c) => c.id == _collectionId).firstOrNull;
    final categoryLabel = summary?.categories.where((c) => c.key == _categoryKey).firstOrNull;

    final modeValue = _isCollection
        ? (current == null ? '' : '${current.name} · ${current.placeCount}곳')
        : (categoryLabel == null
            ? '전체 · ${summary?.totalCount ?? '-'}곳'
            : '${categoryLabel.label} · ${categoryLabel.count}곳');

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
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: AppShadow.soft),
                  child: AppSearchField(hint: '저장된 장소 검색', onChanged: (v) => setState(() => _keyword = v.trim())),
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xs),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), boxShadow: AppShadow.soft),
          child: Row(
            children: [
              Text(_isCollection ? '내 보관함' : '카테고리', style: AppTypography.label.copyWith(color: AppColors.textSecondary)),
              const Spacer(),
              Text(modeValue, style: AppTypography.label.copyWith(color: AppColors.primary)),
            ],
          ),
        ),
        SizedBox(
          height: AppSpacing.chipHeight + 4,
          child: ChipScroller(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            children: _isCollection
                ? [
                    for (final c in collections)
                      AppChip(
                        label: c.name,
                        trailingCount: c.placeCount,
                        selected: c.id == _collectionId,
                        selectedColor: AppColors.ink,
                        onTap: () => _selectCollection(c.id),
                      ),
                  ]
                : [
                    AppChip(
                      label: '전체',
                      trailingCount: summary?.totalCount,
                      selected: _categoryKey == null,
                      selectedColor: AppColors.ink,
                      onTap: () => setState(() {
                        _categoryKey = null;
                        _bounds = null;
                      }),
                    ),
                    for (final cat in summary?.categories ?? const <PlaceCategory>[])
                      AppChip(
                        label: cat.label,
                        trailingCount: cat.count,
                        selected: _categoryKey == cat.key,
                        selectedColor: AppColors.ink,
                        onTap: () => setState(() {
                          _categoryKey = cat.key;
                          _bounds = null;
                        }),
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

  Widget _categorySheet(ScrollController scroll, AsyncValue<List<SavedPlaceItem>> visible) {
    final list = visible.value ?? const <SavedPlaceItem>[];
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        const Center(child: SheetHandle()),
        _sheetHeader(
          title: '이 지역에 저장한 장소',
          subtitle: '지도에 보이는 ${list.length}곳',
          trailing: AppButton(
            label: '목록 펼치기',
            icon: Icons.format_list_bulleted_rounded,
            variant: AppButtonVariant.soft,
            expand: false,
            height: 40,
            onPressed: () => _sheet.animateTo(0.92, duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
          ),
        ),
        _visibleState(visible) ??
            (list.isEmpty
                ? (_markerPoints.isEmpty
                    // 저장 0곳: 찾아서 저장하도록 안내 (07 D32)
                    ? AppEmptyState(
                        compact: true,
                        icon: Icons.bookmark_border_rounded,
                        title: '아직 저장한 곳이 없어요',
                        description: '가고 싶은 곳을 찾아 저장하면 지도에 표시돼요.',
                        actionLabel: '장소 찾기',
                        onAction: () => context.push(AppRoutes.placeSearch),
                      )
                    : AppEmptyState(
                        compact: true,
                        icon: Icons.location_off_outlined,
                        title: '이 근처에 저장한 장소가 없어요',
                        actionLabel: '저장한 장소 전체 보기',
                        onAction: () => _map.fitTo(_markerPoints),
                      ))
                : SizedBox(
                    height: 112,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: AppSpacing.screenPadding,
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
                      itemBuilder: (_, i) => _MapPlaceCard(
                        item: list[i],
                        selected: list[i].place.id == _selectedId,
                        onTap: () => context.push(AppRoutes.place(list[i].place.id)),
                      ),
                    ),
                  )),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, 0),
          child: Text('지도를 움직이면 이 지역의 저장 장소가 갱신돼요.', style: AppTypography.caption),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.sm, AppSpacing.screenH, AppSpacing.md),
          child: Align(alignment: Alignment.centerLeft, child: _autoSearchToggle()),
        ),
        for (final item in list)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            child: PlaceListTile(place: item.place, flat: true, onTap: () => context.push(AppRoutes.place(item.place.id))),
          ),
      ],
    );
  }

  Widget _collectionSheet(ScrollController scroll, AsyncValue<List<SavedPlaceItem>> visible) {
    final collections = ref.watch(collectionsProvider).value ?? const <PlaceCollection>[];
    final current = collections.where((c) => c.id == _collectionId).firstOrNull;
    final list = (visible.value ?? const <SavedPlaceItem>[])
        .where((i) => _listKeyword.isEmpty || i.place.name.contains(_listKeyword))
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
              for (final s in SavedSort.values)
                if (s != SavedSort.nearest || _hasLocation)
                  SheetAction(
                    label: s.label,
                    icon: s == _effectiveSort ? Icons.check_rounded : Icons.sort_rounded,
                    onTap: () => setState(() => _sort = s),
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

  Widget _distanceText(SavedPlaceItem item) {
    final label = item.walkMinutes != null && item.walkMinutes! <= 20
        ? '도보 ${item.walkMinutes}분'
        : (item.distanceMeters == null ? null : formatDistance(item.distanceMeters!));
    if (label == null) return const SizedBox.shrink();
    return Text(label, style: AppTypography.label.copyWith(color: AppColors.primary));
  }

  /// 로딩/오류면 해당 위젯, 데이터가 있으면 null
  Widget? _visibleState(AsyncValue<List<SavedPlaceItem>> v) {
    if (v.hasError && !v.hasValue) {
      return AppErrorState(error: v.error!, compact: true, onRetry: () => ref.invalidate(savedPlacesInBoundsProvider));
    }
    if (!v.hasValue) return const AppLoading(padding: EdgeInsets.all(AppSpacing.lg));
    return null;
  }

  Widget _autoSearchToggle() {
    return Material(
      color: AppColors.bg,
      borderRadius: AppRadius.pillAll,
      child: InkWell(
        borderRadius: AppRadius.pillAll,
        onTap: () => setState(() {
          _autoSearch = !_autoSearch;
          if (!_autoSearch) _bounds = null;
        }),
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

/// 지도 하단 가로 카드
class _MapPlaceCard extends StatelessWidget {
  const _MapPlaceCard({required this.item, required this.selected, required this.onTap});
  final SavedPlaceItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = item.place;
    return SizedBox(
      width: 260,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.6 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                AppNetworkImage(url: p.imageUrl, width: 76, height: 76, radius: 14),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: AppTypography.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        [
                          p.categoryLabel,
                          if (item.walkMinutes != null)
                            '도보 ${item.walkMinutes}분'
                          else if (item.distanceMeters != null)
                            formatDistance(item.distanceMeters!),
                        ].join(' · '),
                        style: AppTypography.caption,
                      ),
                      const SizedBox(height: 4),
                      if (p.rating != null) RatingText(p.rating!, suffix: p.isSaved ? '저장됨' : null),
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
