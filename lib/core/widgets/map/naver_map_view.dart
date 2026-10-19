import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../../../app/theme/app_colors.dart';
import '../../models/geo_point.dart';
import 'apt_map.dart';
import 'map_pin.dart';

/// 네이버 지도 SDK 구현. [AptMap]만 이 위젯을 쓴다 — 화면에서 직접 쓰지 않는다.
///
/// - 마커: 기존 [MapPin] 위젯을 이미지로 그려 아이콘으로 쓴다 (미리보기와 같은 모양).
/// - 카메라: 처음 마커가 생기면 전체가 보이게 맞춘다([fitMarkersOnLoad]). viewport 기반 조회 화면([onCameraIdle] 있음)은
///   이후 마커가 바뀌어도 카메라를 움직이지 않는다 (조회 결과가 카메라를 다시 끌어당기는 루프 방지).
/// - `© NAVER` 로고는 SDK 기본 표기를 그대로 둔다 (숨기지 않는다).
class NaverMapView extends StatefulWidget {
  const NaverMapView({
    super.key,
    required this.markers,
    required this.route,
    required this.onMarkerTap,
    required this.onCameraIdle,
    required this.selectedId,
    required this.bottomPadding,
    required this.topPadding,
    this.controller,
    this.fitMarkersOnLoad = true,
  });

  final List<MapMarker> markers;
  final List<GeoPoint> route;
  final ValueChanged<MapMarker>? onMarkerTap;
  final ValueChanged<GeoBounds>? onCameraIdle;
  final String? selectedId;
  final double bottomPadding;
  final double topPadding;
  final AptMapController? controller;
  final bool fitMarkersOnLoad;

  @override
  State<NaverMapView> createState() => _NaverMapViewState();
}

class _NaverMapViewState extends State<NaverMapView> implements AptMapCommands {
  /// 미리보기 지도와 같은 핀 영역 (라벨 포함). 앵커는 영역 중앙.
  static const _pinSize = Size(120, 76);
  static const _seoulCityHall = NLatLng(37.5666, 126.979);

  NaverMapController? _controller;
  final _icons = <String, NOverlayImage>{};
  Set<String> _fittedIds = const {};
  int _syncToken = 0;

  /// 지도가 준비되기 전에 받은 명령 (준비되면 적용)
  NCameraUpdate? _pendingCamera;
  GeoPoint? _dot;

  EdgeInsets get _contentPadding => EdgeInsets.only(top: widget.topPadding, bottom: widget.bottomPadding);

  @override
  void initState() {
    super.initState();
    widget.controller?.attach(this);
  }

  @override
  void dispose() {
    widget.controller?.attach(null);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NaverMapView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?.attach(null);
      widget.controller?.attach(this);
    }
    if (old.markers != widget.markers || old.route != widget.route || old.selectedId != widget.selectedId) {
      _sync();
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = focusBounds([...widget.markers.map((m) => m.point), ...widget.route]);
    return NaverMap(
      options: NaverMapViewOptions(
        initialCameraPosition: NCameraPosition(
          target: initial == null ? _seoulCityHall : _latLng(_center(initial)),
          zoom: 14,
        ),
        // 로고·축척·카메라 중심이 상단 칩/하단 시트에 가려지지 않게 한다 (logoMargin은 이 안쪽 기준)
        contentPadding: _contentPadding,
        locale: const Locale('ko'),
        indoorEnable: false,
        // 지도 기본 심볼(가게 이름 등) 탭은 우리 화면 동작이 없으므로 소비만 한다.
        consumeSymbolTapEvents: true,
      ),
      onMapReady: (c) {
        _controller = c;
        _applyDot(c);
        final pending = _pendingCamera;
        _pendingCamera = null;
        if (pending != null) c.updateCamera(pending);
        _sync();
      },
      onCameraIdle: widget.onCameraIdle == null ? null : _reportBounds,
    );
  }

  @override
  void moveTo(GeoPoint target, {double zoom = 15}) =>
      _camera(NCameraUpdate.scrollAndZoomTo(target: _latLng(target), zoom: zoom));

  @override
  void fitTo(List<GeoPoint> points) => _camera(_fitUpdate(points));

  /// 위치는 LocationService가 받는다 — SDK 기본 추적기는 정확한 위치(FINE)만 확인해서 쓰지 않는다.
  @override
  void showLocationDot(GeoPoint? point) {
    _dot = point;
    final c = _controller;
    if (c != null) _applyDot(c);
  }

  void _applyDot(NaverMapController c) {
    final overlay = c.getLocationOverlay();
    final dot = _dot;
    if (dot != null) overlay.setPosition(_latLng(dot));
    overlay.setIsVisible(dot != null);
  }

  void _camera(NCameraUpdate update) {
    final c = _controller;
    if (c == null) {
      _pendingCamera = update;
    } else {
      c.updateCamera(update);
    }
  }

  Future<void> _reportBounds() async {
    final c = _controller;
    if (c == null) return;
    final b = await c.getContentBounds(withPadding: true);
    if (!mounted) return;
    widget.onCameraIdle?.call(GeoBounds(
      southWest: GeoPoint(b.southWest.latitude, b.southWest.longitude),
      northEast: GeoPoint(b.northEast.latitude, b.northEast.longitude),
    ));
  }

  /// 오버레이를 현재 props로 다시 그린다.
  /// TODO(naver-map): 마커가 많아지면 전체 교체 대신 id 기준 diff로 바꾼다 (선택 변경 시 깜빡임).
  Future<void> _sync() async {
    final c = _controller;
    if (c == null) return;
    final token = ++_syncToken;

    final overlays = <NAddableOverlay>{};
    if (widget.route.length > 1) {
      overlays.add(NPathOverlay(
        id: 'route',
        // SDK가 List만 직렬화한다 (lazy Iterable이면 예외 → 같은 배치의 마커까지 안 그려짐)
        coords: widget.route.map(_latLng).toList(),
        width: 5,
        color: AppColors.primary,
        outlineWidth: 0,
      ));
    }
    for (final m in widget.markers) {
      final marker = NMarker(
        id: m.id,
        position: _latLng(m.point),
        icon: await _iconFor(m),
        size: _pinSize,
        anchor: const NPoint(0.5, 0.5),
      )..setZIndex(m.id == widget.selectedId ? 10 : 0);
      if (widget.onMarkerTap != null) marker.setOnTapListener((_) => widget.onMarkerTap!(m));
      overlays.add(marker);
    }
    // 아이콘을 그리는 동안 새 props가 들어왔으면 이번 결과는 버린다.
    if (!mounted || token != _syncToken) return;

    await c.clearOverlays();
    await c.addOverlayAll(overlays);
    await _fitIfNeeded(c);
  }

  Future<void> _fitIfNeeded(NaverMapController c) async {
    final ids = {for (final m in widget.markers) m.id};
    final firstFit = _fittedIds.isEmpty;
    final viewportDriven = widget.onCameraIdle != null;
    if (!widget.fitMarkersOnLoad || ids.isEmpty || (!firstFit && (viewportDriven || _sameSet(ids, _fittedIds)))) return;
    _fittedIds = ids;

    await c.updateCamera(_fitUpdate([...widget.markers.map((m) => m.point), ...widget.route]));
  }

  static NCameraUpdate _fitUpdate(List<GeoPoint> points) {
    final bounds = focusBounds(points)!;
    const edge = 56.0;
    return points.length == 1
        ? NCameraUpdate.scrollAndZoomTo(target: _latLng(points.first), zoom: 15)
        : NCameraUpdate.fitBounds(
            NLatLngBounds(southWest: _latLng(bounds.southWest), northEast: _latLng(bounds.northEast)),
            padding: const EdgeInsets.all(edge),
          );
  }

  Future<NOverlayImage> _iconFor(MapMarker m) async {
    final selected = m.id == widget.selectedId;
    final key = '${m.kind.name}|${m.number}|${m.label}|${m.icon?.codePoint}|${m.color?.toARGB32()}|$selected';
    return _icons[key] ??= await NOverlayImage.fromWidget(
      context: context,
      size: _pinSize,
      widget: Center(
        child: MapPin(
          kind: m.kind,
          number: m.number,
          label: m.label,
          icon: m.icon,
          color: m.color,
          selected: selected,
        ),
      ),
    );
  }

  static NLatLng _latLng(GeoPoint p) => NLatLng(p.lat, p.lng);

  static GeoPoint _center(GeoBounds b) =>
      GeoPoint((b.southWest.lat + b.northEast.lat) / 2, (b.southWest.lng + b.northEast.lng) / 2);

  static bool _sameSet(Set<String> a, Set<String> b) => a.length == b.length && a.containsAll(b);
}
