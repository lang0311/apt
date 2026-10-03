import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../config/env.dart';
import '../../models/geo_point.dart';
import 'map_pin.dart';

/// 지도 마커 (SDK 타입과 분리된 앱 모델)
class MapMarker {
  const MapMarker({
    required this.id,
    required this.point,
    required this.kind,
    this.number,
    this.label,
    this.icon,
    this.color,
  });

  final String id;
  final GeoPoint point;
  final MapPinKind kind;
  final int? number;
  final String? label;
  final IconData? icon;
  final Color? color;
}

/// 공통 지도 위젯. 네이버 지도(확정, docs/02 §6)를 감싼다.
///
/// NEEDS: 네이버 지도 클라이언트 ID. `flutter_naver_map` 도입 시 [_NaverMapView]를 구현하고
/// [Env.naverMapClientId]가 있으면 그것을 사용한다. 그 전까지는 [_PreviewMap]으로
/// 마커·경로 배치만 확인한다. 실제 지도에서는 SDK의 `© NAVER` 표기를 그대로 유지한다.
class AptMap extends StatelessWidget {
  const AptMap({
    super.key,
    required this.markers,
    this.route = const [],
    this.onMarkerTap,
    this.onCameraIdle,
    this.selectedId,
    this.bottomPadding = 0,
  });

  final List<MapMarker> markers;

  /// 경로 꼭짓점. 도로를 따르는 polyline 데이터의 제공 주체는 미정 (NEEDS BACKEND).
  final List<GeoPoint> route;
  final ValueChanged<MapMarker>? onMarkerTap;

  /// 지도 이동이 멈췄을 때 보이는 영역 (viewport 기반 조회 + debounce는 호출 측에서)
  final ValueChanged<GeoBounds>? onCameraIdle;
  final String? selectedId;

  /// 하단 시트에 가려지는 높이 (마커 배치 시 제외)
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    if (Env.naverMapClientId.isNotEmpty) {
      // TODO(naver-map): flutter_naver_map 연동 후 실제 지도로 교체
    }
    return _PreviewMap(
      markers: markers,
      route: route,
      onMarkerTap: onMarkerTap,
      onCameraIdle: onCameraIdle,
      selectedId: selectedId,
      bottomPadding: bottomPadding,
    );
  }
}

/// SDK 키가 없을 때 쓰는 지도 미리보기. 마커 좌표를 화면에 투영해 배치만 보여준다.
class _PreviewMap extends StatefulWidget {
  const _PreviewMap({
    required this.markers,
    required this.route,
    required this.onMarkerTap,
    required this.onCameraIdle,
    required this.selectedId,
    required this.bottomPadding,
  });

  final List<MapMarker> markers;
  final List<GeoPoint> route;
  final ValueChanged<MapMarker>? onMarkerTap;
  final ValueChanged<GeoBounds>? onCameraIdle;
  final String? selectedId;
  final double bottomPadding;

  @override
  State<_PreviewMap> createState() => _PreviewMapState();
}

class _PreviewMapState extends State<_PreviewMap> {
  GeoBounds? _reported;

  GeoBounds? get _bounds => GeoBounds.around([...widget.markers.map((m) => m.point), ...widget.route]);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportBounds());
  }

  @override
  void didUpdateWidget(covariant _PreviewMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 마커가 바뀌면(필터 변경) 보이는 영역을 다시 알린다 — 실제 지도의 카메라 이동에 해당
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportBounds());
  }

  void _reportBounds() {
    final b = _bounds;
    if (!mounted || b == null || widget.onCameraIdle == null) return;
    if (_reported != null &&
        _reported!.southWest == b.southWest &&
        _reported!.northEast == b.northEast) {
      return;
    }
    _reported = b;
    widget.onCameraIdle!(b);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      final usable = Rect.fromLTRB(44, 64, size.width - 44, math.max(110, size.height - widget.bottomPadding - 44));
      final project = _projector(usable);
      final routeOffsets = widget.route.map(project).toList();

      return ClipRect(
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _MapBackgroundPainter())),
            if (routeOffsets.length > 1)
              Positioned.fill(child: CustomPaint(painter: _RoutePainter(routeOffsets))),
            for (final m in widget.markers)
              _positioned(project(m.point), m),
            Positioned(
              right: 10,
              bottom: widget.bottomPadding + 8,
              child: Text('지도 미리보기 · NAVER 지도 연동 예정', style: AppTypography.caption.copyWith(fontSize: 10)),
            ),
          ],
        ),
      );
    });
  }

  Offset Function(GeoPoint) _projector(Rect area) {
    final b = _bounds;
    if (b == null) return (_) => area.center;
    final latSpan = math.max(b.northEast.lat - b.southWest.lat, 0.002);
    final lngSpan = math.max(b.northEast.lng - b.southWest.lng, 0.002);
    return (p) => Offset(
          area.left + (p.lng - b.southWest.lng) / lngSpan * area.width,
          area.bottom - (p.lat - b.southWest.lat) / latSpan * area.height,
        );
  }

  Widget _positioned(Offset o, MapMarker m) {
    const w = 120.0, h = 76.0;
    return Positioned(
      left: o.dx - w / 2,
      top: o.dy - h / 2,
      width: w,
      height: h,
      child: Center(
        child: GestureDetector(
          onTap: widget.onMarkerTap == null ? null : () => widget.onMarkerTap!(m),
          child: MapPin(
            kind: m.kind,
            number: m.number,
            label: m.label,
            icon: m.icon,
            color: m.color,
            selected: m.id == widget.selectedId,
          ),
        ),
      ),
    );
  }
}

class _MapBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF3EFE8));
    final park = Paint()..color = const Color(0xFFDDEFD9);
    canvas.drawCircle(Offset(size.width * 0.08, size.height * 0.62), size.width * 0.16, park);
    canvas.drawCircle(Offset(size.width * 0.92, size.height * 0.3), size.width * 0.12, park);

    final minor = Paint()
      ..color = Colors.white
      ..strokeWidth = 5;
    for (var i = 1; i < 8; i++) {
      final y = size.height * i / 8;
      canvas.drawLine(Offset(0, y + 12), Offset(size.width, y - 12), minor);
    }
    for (var i = 1; i < 6; i++) {
      final x = size.width * i / 6;
      canvas.drawLine(Offset(x - 10, 0), Offset(x + 10, size.height), minor);
    }
    final major = Paint()
      ..color = const Color(0xFFFFE8B8)
      ..strokeWidth = 9;
    canvas.drawLine(Offset(0, size.height * 0.28), Offset(size.width, size.height * 0.18), major);
    canvas.drawLine(Offset(size.width * 0.62, 0), Offset(size.width * 0.5, size.height), major);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RoutePainter extends CustomPainter {
  _RoutePainter(this.points);
  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2 - 18);
      path.quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RoutePainter old) => old.points != points;
}
