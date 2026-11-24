import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../models/geo_point.dart';
import 'apt_map.dart';
import 'map_pin.dart';

/// SDK 키가 없을 때 쓰는 지도 미리보기. 마커 좌표를 화면에 투영해 배치만 보여준다.
class PreviewMap extends StatefulWidget {
  const PreviewMap({
    super.key,
    required this.markers,
    required this.route,
    required this.onMarkerTap,
    required this.onCameraIdle,
    required this.selectedId,
    required this.bottomPadding,
    required this.topPadding,
    this.clearCorner,
    this.compact = false,
  });

  final List<MapMarker> markers;
  final List<GeoPoint> route;
  final ValueChanged<MapMarker>? onMarkerTap;
  final ValueChanged<GeoBounds>? onCameraIdle;
  final String? selectedId;
  final double bottomPadding;
  final double topPadding;

  /// 오른쪽 아래에 떠 있는 버튼 크기(여백 포함). 핀을 이 자리 밖으로 옮긴다 (v2-7)
  final Size? clearCorner;

  /// 작은 지도(코스 · 장소 상세). 이름표를 왼쪽 위 작은 칩 '지도 미리보기'로 둔다 (v2-7)
  final bool compact;

  @override
  State<PreviewMap> createState() => _PreviewMapState();
}

class _PreviewMapState extends State<PreviewMap> {
  GeoBounds? _reported;

  GeoBounds? get _bounds => focusBounds([...widget.markers.map((m) => m.point), ...widget.route]);

  bool _visible(GeoBounds? b, GeoPoint p) {
    if (b == null) return true;
    const e = 1e-9;
    return p.lat >= b.southWest.lat - e && p.lat <= b.northEast.lat + e && p.lng >= b.southWest.lng - e && p.lng <= b.northEast.lng + e;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportBounds());
  }

  @override
  void didUpdateWidget(covariant PreviewMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 마커가 바뀌면(필터 변경) 보이는 영역을 다시 알린다 — 실제 지도의 카메라 이동에 해당
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportBounds());
  }

  void _reportBounds() {
    final b = _bounds;
    if (!mounted || b == null || widget.onCameraIdle == null) return;
    if (_reported == b) return;
    _reported = b;
    widget.onCameraIdle!(b);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final top = widget.topPadding + 44;
        final usable = Rect.fromLTRB(44, top, size.width - 44, math.max(top + 60, size.height - widget.bottomPadding - 44));
        final bounds = _bounds;
        final project = _projector(usable, bounds);
        final shown = [for (final m in widget.markers) if (_visible(bounds, m.point)) m];
        final placed = _layout([for (final m in shown) project(m.point)], usable, size);
        final at = {for (final (i, m) in shown.indexed) m.point: placed[i]};
        final routeOffsets = widget.route.where((p) => _visible(bounds, p)).map((p) => at[p] ?? project(p)).toList();

        return ClipRect(
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _MapBackgroundPainter())),
              if (routeOffsets.length > 1) Positioned.fill(child: CustomPaint(painter: _RoutePainter(routeOffsets))),
              for (final (i, m) in shown.indexed) _positioned(placed[i], m),
              if (widget.compact)
                Positioned(left: 8, top: 8, child: const _PreviewTag())
              else
                Positioned(
                  right: 10,
                  bottom: widget.bottomPadding + 8,
                  child: Text('지도 미리보기 · NAVER 지도 연동 예정', style: AppTypography.caption),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 핀끼리 한 점에 겹치지 않게 벌리고([_minGap]), [PreviewMap.clearCorner] 자리에 든 핀은 위로 올린다.
  List<Offset> _layout(List<Offset> points, Rect area, Size size) {
    final out = [...points];
    final corner = widget.clearCorner;
    Offset keep(Offset o) {
      var p = Offset(o.dx.clamp(area.left, area.right), o.dy.clamp(area.top, math.max(area.top, area.bottom)));
      if (corner != null) {
        final zoneLeft = size.width - corner.width - _pinRadius, zoneTop = size.height - corner.height - _pinRadius;
        if (p.dx > zoneLeft && p.dy > zoneTop) p = Offset(p.dx, math.max(area.top, zoneTop));
      }
      return p;
    }

    for (var round = 0; round < 6; round++) {
      for (var i = 0; i < out.length; i++) {
        for (var j = i + 1; j < out.length; j++) {
          var d = out[j] - out[i];
          if (d.distance >= _minGap) continue;
          if (d.distance < 0.5) d = Offset(j.isEven ? 1 : -1, 0);
          final push = d / d.distance * ((_minGap - d.distance) / 2);
          out[i] -= push;
          out[j] += push;
        }
      }
      for (var i = 0; i < out.length; i++) {
        out[i] = keep(out[i]);
      }
    }
    return out;
  }

  static const double _pinRadius = 20;
  static const double _minGap = 34;

  Offset Function(GeoPoint) _projector(Rect area, GeoBounds? b) {
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
          child: MapPin(kind: m.kind, number: m.number, label: m.label, icon: m.icon, color: m.color, selected: m.id == widget.selectedId),
        ),
      ),
    );
  }
}

/// 작은 지도 왼쪽 위 '지도 미리보기' 칩 (SDK 키가 없을 때만)
class _PreviewTag extends StatelessWidget {
  const _PreviewTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(6)),
      child: Text('지도 미리보기', style: AppTypography.caption),
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
