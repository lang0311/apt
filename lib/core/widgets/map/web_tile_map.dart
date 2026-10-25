import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme/app_colors.dart';
import '../../models/geo_point.dart';
import 'apt_map.dart';
import 'map_pin.dart';

/// 웹 지도: OpenStreetMap 타일 (07 D29). 앱(Android·iOS)은 네이버 지도를 쓴다.
/// [AptMap]이 `kIsWeb`일 때만 고른다. 화면은 이 위젯을 직접 쓰지 않는다.

/// 브라우저가 이미지를 직접 받게 한다 (타일 서버 CORS 회피).
class _BrowserTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      NetworkImage(getTileUrl(coordinates, options));
}

class WebTileMap extends StatefulWidget {
  const WebTileMap({
    super.key,
    required this.markers,
    required this.route,
    this.onMarkerTap,
    this.onCameraIdle,
    this.selectedId,
    this.bottomPadding = 0,
    this.topPadding = 0,
    this.controller,
    this.fitMarkersOnLoad = true,
  });
  final List<MapMarker> markers;
  final List<GeoPoint> route;
  final ValueChanged<MapMarker>? onMarkerTap;
  final ValueChanged<GeoBounds>? onCameraIdle;
  final String? selectedId;
  final double bottomPadding, topPadding;
  final AptMapController? controller;
  final bool fitMarkersOnLoad;
  @override
  State<WebTileMap> createState() => _WebTileMapState();
}

class _WebTileMapState extends State<WebTileMap> implements AptMapCommands {
  final map = MapController();
  bool ready = false;
  GeoPoint? location;
  Timer? idle;
  LatLng point(GeoPoint p) => LatLng(p.lat, p.lng);
  @override
  void initState() {
    super.initState();
    widget.controller?.attach(this);
  }

  @override
  void dispose() {
    idle?.cancel();
    widget.controller?.attach(null);
    map.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant WebTileMap old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?.attach(null);
      widget.controller?.attach(this);
    }
    if (ready &&
        widget.fitMarkersOnLoad &&
        old.markers.map((m) => m.id).join('|') !=
            widget.markers.map((m) => m.id).join('|')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) fitTo(widget.markers.map((m) => m.point).toList());
      });
    }
  }

  @override
  void moveTo(GeoPoint target, {double zoom = 15}) {
    if (ready) map.move(point(target), zoom);
  }

  @override
  void fitTo(List<GeoPoint> points) {
    if (!ready || points.isEmpty) return;
    final b = focusBounds(points)!;
    map.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(point(b.southWest), point(b.northEast)),
        padding: EdgeInsets.fromLTRB(
          40,
          40 + widget.topPadding,
          40,
          40 + widget.bottomPadding,
        ),
        maxZoom: 16,
      ),
    );
  }

  @override
  void showLocationDot(GeoPoint? p) {
    setState(() => location = p);
  }

  void changed(MapCamera camera) {
    idle?.cancel();
    idle = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final b = camera.visibleBounds;
      widget.onCameraIdle?.call(
        GeoBounds(
          southWest: GeoPoint(b.south, b.west),
          northEast: GeoPoint(b.north, b.east),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.fitMarkersOnLoad
        ? focusBounds(widget.markers.map((m) => m.point).toList())
        : null;
    return FlutterMap(
      mapController: map,
      options: MapOptions(
        initialCenter: widget.markers.isEmpty
            ? const LatLng(37.557, 126.925)
            : point(widget.markers.first.point),
        initialZoom: 14,
        initialCameraFit: initial == null
            ? null
            : CameraFit.bounds(
                bounds: LatLngBounds(
                  point(initial.southWest),
                  point(initial.northEast),
                ),
                padding: const EdgeInsets.all(40),
                maxZoom: 16,
              ),
        onMapReady: () {
          ready = true;
          changed(map.camera);
        },
        onPositionChanged: (camera, gesture) => changed(camera),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.teamjkk.apt',
          tileProvider: _BrowserTileProvider(),
          tileDisplay: const TileDisplay.instantaneous(),
          errorTileCallback: (tile, error, stack) =>
              debugPrint('[map-tile] $error'),
        ),
        if (widget.route.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.route.map(point).toList(),
                strokeWidth: 5,
                color: AppColors.primary,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            for (final m in widget.markers)
              Marker(
                point: point(m.point),
                width: 60,
                height: 52,
                child: GestureDetector(
                  onTap: () => widget.onMarkerTap?.call(m),
                  child: Tooltip(
                    message: m.label ?? '',
                    child: MapPin(
                      kind: m.kind,
                      number: m.number,
                      icon: m.icon,
                      color: m.color,
                      selected: m.id == widget.selectedId,
                    ),
                  ),
                ),
              ),
            if (location != null)
              Marker(
                point: point(location!),
                width: 16,
                height: 16,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
              ),
          ],
        ),
        const SimpleAttributionWidget(
          source: Text('OpenStreetMap contributors'),
        ),
      ],
    );
  }
}
