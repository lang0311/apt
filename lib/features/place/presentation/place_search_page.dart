import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di/repositories.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/models/geo_point.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/map/apt_map.dart';
import '../../../core/widgets/map/map_pin.dart';
import '../../../core/widgets/overlays.dart';
import '../../../core/widgets/states.dart';
import '../../saved/presentation/saved_providers.dart';
import '../../saved/presentation/widgets/category_style.dart';
import '../../saved/presentation/widgets/collection_select_sheet.dart';
import '../../saved/presentation/widgets/place_image.dart';
import '../domain/place.dart';
import 'place_search_providers.dart';

/// 지도에서 검색하기 (추출 탭, 07 D32). 찾은 곳을 지도 핀과 카드 목록으로 보여 주고,
/// 카드에서 바로 저장하거나 보관함에 담는다. 카드 모양은 이름·설명·주소·버튼 + 오른쪽 이미지.
class PlaceSearchPage extends ConsumerStatefulWidget {
  const PlaceSearchPage({super.key, this.initialQuery});

  /// 들어오자마자 찾을 검색어 (없으면 검색칸에 커서를 두고 기다린다)
  final String? initialQuery;

  @override
  ConsumerState<PlaceSearchPage> createState() => _PlaceSearchPageState();
}

class _PlaceSearchPageState extends ConsumerState<PlaceSearchPage> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  final _map = AptMapController();
  final _sheet = DraggableScrollableController();

  PlaceSearchQuery? _query;
  String? _selectedId;

  /// 카드 한 장만 보기 (핀이나 카드를 눌렀을 때)
  bool _single = false;

  /// 결과를 처음 맞춘 지도 가운데와 지금 가운데. 많이 움직이면 '현재 지도에서 검색하기'를 띄운다.
  GeoPoint? _fittedCenter;
  GeoPoint? _center;

  /// 이 화면에서 저장·담기한 결과 (목록을 다시 받기 전까지 화면에 바로 반영)
  final _savedIds = <String>{};
  final _collectionIds = <String, Set<String>>{};
  final _busyIds = <String>{};

  static const _sheetInitial = 0.5;
  static const _moveThresholdMeters = 300.0;

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuery?.trim();
    if (q != null && q.isNotEmpty) {
      _text.text = q;
      _query = PlaceSearchQuery(q);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    _sheet.dispose();
    super.dispose();
  }

  void _search({GeoPoint? near}) {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    _focus.unfocus();
    setState(() {
      _query = PlaceSearchQuery(text, near: near);
      _selectedId = null;
      _single = false;
      _fittedCenter = null;
    });
  }

  void _clear() {
    _text.clear();
    setState(() {
      _query = null;
      _selectedId = null;
      _single = false;
    });
    _focus.requestFocus();
  }

  /// 새 결과가 오면 결과가 모두 보이게 맞춘다 (지도는 이후 이동을 사용자에게 맡긴다).
  void _fitTo(List<Place> places) {
    final points = [for (final p in places) ?p.location];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || points.isEmpty) return;
      // 맞춘 뒤 처음 멈춘 자리를 기준으로 삼는다 (맞추는 이동은 '지도를 움직였다'로 보지 않는다)
      _fittedCenter = null;
      _map.fitTo(points);
    });
  }

  void _onCameraIdle(GeoBounds b) {
    final center = b.center;
    if (_fittedCenter == null) {
      _fittedCenter = center;
      return;
    }
    setState(() => _center = center);
  }

  bool get _mapMoved =>
      _center != null && _fittedCenter != null && _center!.distanceTo(_fittedCenter!) > _moveThresholdMeters;

  void _select(Place p) {
    setState(() {
      _selectedId = p.id;
      _single = true;
    });
    if (p.location != null) _map.moveTo(p.location!);
  }

  bool _isSaved(Place p) => p.isSaved || _savedIds.contains(p.id);

  Future<void> _save(Place p) async {
    if (_isSaved(p) || _busyIds.contains(p.id)) return;
    setState(() => _busyIds.add(p.id));
    try {
      await ref.read(savedRepositoryProvider).savePlaces(placeIds: [p.id], collectionIds: const []);
      if (!mounted) return;
      invalidateSavedData(ref);
      setState(() => _savedIds.add(p.id));
      final canCollect = ref.read(collectionsSupportedProvider);
      showAppSnackBar(
        context,
        '저장됨에 추가했어요.',
        actionLabel: canCollect ? '보관함에 담기' : null,
        onAction: canCollect ? () => _pickCollections(p) : null,
      );
    } catch (e) {
      if (mounted) showAppSnackBar(context, failureMessage(e));
    } finally {
      if (mounted) setState(() => _busyIds.remove(p.id));
    }
  }

  /// 보관함 고르기 시트 (추출 결과와 같은 시트, 07 D26). 고르면 저장도 같이 된다.
  Future<void> _pickCollections(Place p) async {
    if (!ref.read(collectionsSupportedProvider)) {
      showAppSnackBar(context, const NotImplementedFailure('보관함').message);
      return;
    }
    final repo = ref.read(savedRepositoryProvider);
    try {
      // 이미 저장한 곳은 지금 들어 있는 보관함을 체크해 두고 시작한다 (시트 결과로 통째로 바꾸기 때문)
      final current = _collectionIds[p.id] ??
          (_isSaved(p) ? (await repo.fetchPlaceCollectionIds(p.id)).toSet() : <String>{});
      if (!mounted) return;
      final picked = await showCollectionSelectSheet(context, placeName: p.name, initialSelected: current);
      if (picked == null || !mounted) return;
      setState(() => _busyIds.add(p.id));
      await repo.setPlaceCollections(placeId: p.id, collectionIds: picked.collectionIds.toList());
      if (!mounted) return;
      invalidateSavedData(ref);
      setState(() {
        _savedIds.add(p.id);
        _collectionIds[p.id] = picked.collectionIds;
      });
      final names = await _collectionNames(picked.collectionIds);
      if (!mounted) return;
      showAppSnackBar(
        context,
        names.isEmpty
            ? '저장됨에 추가했어요.'
            : names.length == 1
                ? '${names.first}에 저장했어요.'
                : '보관함 ${names.length}곳에 저장했어요.',
      );
    } catch (e) {
      if (mounted) showAppSnackBar(context, failureMessage(e));
    } finally {
      if (mounted) setState(() => _busyIds.remove(p.id));
    }
  }

  Future<List<String>> _collectionNames(Set<String> ids) async {
    if (ids.isEmpty) return const [];
    final all = await ref.read(collectionsProvider.future);
    return [for (final c in all) if (ids.contains(c.id)) c.name];
  }

  String? _collectionLabel(Place p) {
    final ids = _collectionIds[p.id];
    if (ids == null || ids.isEmpty) return null;
    final all = ref.watch(collectionsProvider).value ?? const [];
    final names = [for (final c in all) if (ids.contains(c.id)) c.name];
    if (names.isEmpty) return null;
    return names.length == 1 ? names.first : '${names.first} 외 ${names.length - 1}';
  }

  @override
  Widget build(BuildContext context) {
    final query = _query;
    if (query == null) return _beforeSearch();

    final results = ref.watch(placeSearchProvider(query));
    ref.listen(placeSearchProvider(query), (_, next) {
      if (next.hasValue) _fitTo(next.value!);
    });
    final places = results.value ?? const <Place>[];
    final selected = places.where((p) => p.id == _selectedId).firstOrNull;

    final markers = [
      for (final p in places)
        if (p.location != null)
          MapMarker(
            id: p.id,
            point: p.location!,
            kind: _isSaved(p) ? MapPinKind.place : MapPinKind.result,
            icon: CategoryStyle.of(p.categoryKey).icon,
            color: CategoryStyle.of(p.categoryKey).color,
            label: p.id == _selectedId ? p.name : null,
          ),
    ];

    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        final top = MediaQuery.paddingOf(context).top;
        return Stack(
          children: [
            Positioned.fill(
              child: AptMap(
                markers: markers,
                selectedId: _selectedId,
                bottomPadding: _single ? 200 : c.maxHeight * _sheetInitial,
                topPadding: top + 120,
                onCameraIdle: _onCameraIdle,
                onMarkerTap: (m) {
                  final p = places.where((p) => p.id == m.id).firstOrNull;
                  if (p != null) _select(p);
                },
                controller: _map,
              ),
            ),
            SafeArea(child: _topBar(onMap: true)),
            if (_single && selected != null) ...[
              Positioned(
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.md,
                child: Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  elevation: 3,
                  shadowColor: const Color(0x3314223A),
                  clipBehavior: Clip.antiAlias,
                  child: _card(selected),
                ),
              ),
            ] else
              DraggableScrollableSheet(
                controller: _sheet,
                initialChildSize: _sheetInitial,
                minChildSize: 0.2,
                maxChildSize: 0.92,
                snap: true,
                builder: (context, scroll) => DecoratedBox(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
                    boxShadow: AppShadow.soft,
                  ),
                  child: _resultList(scroll, results, query),
                ),
              ),
          ],
        );
      }),
    );
  }

  /// 검색 전: 검색칸과 안내 한 줄
  Widget _beforeSearch() {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _topBar(onMap: false),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, 0),
              child: Text(
                '가게 이름으로 찾아요. 지점이 여러 곳이면 동네 이름을 같이 넣어 보세요.',
                style: AppTypography.meta,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar({required bool onMap}) {
    final field = AppSearchField(
      hint: '가게 이름이나 지점명',
      controller: _text,
      focusNode: _focus,
      autofocus: !onMap,
      bordered: !onMap,
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) => _search(),
      trailing: _text.text.isEmpty
          ? null
          : IconButton(
              tooltip: '지우기',
              onPressed: _clear,
              icon: const Icon(Icons.cancel_rounded, size: 20, color: AppColors.textHint),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, 0),
          child: Row(
            children: [
              AppIconBox(icon: Icons.chevron_left_rounded, size: 48, tooltip: '뒤로', onPressed: () => context.pop()),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: onMap
                    ? DecoratedBox(
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: AppShadow.soft),
                        child: field,
                      )
                    : field,
              ),
            ],
          ),
        ),
        if (onMap && _mapMoved && !_single)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: _AreaSearchButton(onPressed: () => _search(near: _center)),
          ),
        if (onMap && _single)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: _AreaSearchButton(
              label: '목록 보기',
              icon: Icons.format_list_bulleted_rounded,
              onPressed: () => setState(() => _single = false),
            ),
          ),
      ],
    );
  }

  Widget _resultList(ScrollController scroll, AsyncValue<List<Place>> results, PlaceSearchQuery query) {
    final count = results.value?.length;
    return ListView(
      controller: scroll,
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.xl),
      children: [
        const Center(child: SheetHandle()),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xs, AppSpacing.screenH, AppSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(query.near == null ? '찾은 곳' : '이 지역에서 찾은 곳', style: AppTypography.title),
              const SizedBox(width: AppSpacing.xs),
              if (count != null) Text('$count곳', style: AppTypography.meta),
            ],
          ),
        ),
        AsyncValueView<List<Place>>(
          value: results,
          compactError: true,
          loading: const SkeletonList(count: 3),
          onRetry: () => ref.invalidate(placeSearchProvider(query)),
          isEmpty: (list) => list.isEmpty,
          empty: AppEmptyState(
            compact: true,
            icon: Icons.search_off_rounded,
            title: '\'${query.text}\'로 찾은 곳이 없어요',
            description: '이름을 줄이거나 동네 이름을 같이 넣어 보세요.',
          ),
          data: (list) => Column(
            children: [
              for (final p in list) ...[
                const Divider(height: 1, thickness: 1, color: AppColors.divider),
                _card(p),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _card(Place p) {
    return PlaceSearchCard(
      place: p,
      saved: _isSaved(p),
      collectionLabel: _collectionLabel(p),
      busy: _busyIds.contains(p.id),
      highlighted: !_single && p.id == _selectedId,
      onTap: () => _select(p),
      onSave: () => _save(p),
      onCollections: () => _pickCollections(p),
    );
  }
}

/// 찾은 장소 카드: 이름 · 설명(업종) · 주소 · [저장] [보관함] + 오른쪽 이미지.
/// 팀 서버는 사진·소개를 주지 않아 이미지는 업종 아이콘으로 대신한다 (NEEDS BACKEND).
class PlaceSearchCard extends StatelessWidget {
  const PlaceSearchCard({
    super.key,
    required this.place,
    required this.saved,
    required this.onSave,
    required this.onCollections,
    this.onTap,
    this.collectionLabel,
    this.busy = false,
    this.highlighted = false,
  });

  final Place place;
  final bool saved;
  final String? collectionLabel;
  final bool busy;
  final bool highlighted;
  final VoidCallback? onTap;
  final VoidCallback onSave;
  final VoidCallback onCollections;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted ? AppColors.primarySoft : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: AppTypography.bodyStrong.copyWith(fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (place.categoryLabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(place.categoryLabel, style: AppTypography.meta),
                    ],
                    if (place.address.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(place.address, style: AppTypography.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: AppSpacing.xxs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      children: [
                        _CardButton(
                          icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                          label: saved ? '저장됨' : '저장',
                          active: saved,
                          busy: busy && !saved,
                          semanticLabel: saved ? '${place.name} 저장됨' : '${place.name} 저장',
                          onPressed: saved || busy ? null : onSave,
                        ),
                        _CardButton(
                          icon: Icons.create_new_folder_outlined,
                          label: collectionLabel ?? '보관함',
                          active: collectionLabel != null,
                          semanticLabel: '${place.name} 보관함에 담기',
                          onPressed: busy ? null : onCollections,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              PlaceImage(place: place, width: 72, height: 72, radius: 12, iconSize: 26),
            ],
          ),
        ),
      ),
    );
  }
}

/// 카드 아래 둥근 버튼. 보이는 높이 34, 누르는 영역 44.
class _CardButton extends StatelessWidget {
  const _CardButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.semanticLabel,
    required this.onPressed,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool busy;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final fg = active ? AppColors.primary : AppColors.textPrimary;
    final shape = StadiumBorder(side: BorderSide(color: active ? const Color(0xFF9FBDFD) : AppColors.border));
    return Semantics(
      button: true,
      label: semanticLabel,
      enabled: onPressed != null,
      excludeSemantics: true,
      onTap: onPressed,
      child: SizedBox(
        height: 44,
        // 가로로 늘어나지 않게 (Wrap 안에서 버튼 두 개가 한 줄에 오도록)
        child: Center(
          widthFactor: 1,
          child: Material(
            color: active ? AppColors.primarySoft : AppColors.surfaceRaised,
            shape: shape,
            child: InkWell(
              customBorder: shape,
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    busy
                        ? SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
                        : Icon(icon, size: 16, color: fg),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Text(
                        label,
                        style: AppTypography.meta.copyWith(color: fg, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 검색칸 아래 흰 알약 버튼 ('현재 지도에서 검색하기', '목록 보기')
class _AreaSearchButton extends StatelessWidget {
  const _AreaSearchButton({
    required this.onPressed,
    this.label = '현재 지도에서 검색하기',
    this.icon = Icons.refresh_rounded,
  });

  final VoidCallback onPressed;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceRaised,
      shape: const StadiumBorder(),
      elevation: 2,
      shadowColor: const Color(0x3314223A),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: AppColors.primary),
                const SizedBox(width: 5),
                Text(label, style: AppTypography.label.copyWith(color: AppColors.textPrimary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
