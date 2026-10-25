import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/geo_point.dart';
import 'map_pin.dart';
import 'naver_map_sdk.dart';
import 'naver_map_view.dart';
import 'preview_map.dart';
import 'web_tile_map.dart';

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

/// 처음 보여줄 영역. 멀리 떨어진 장소(다른 지역) 하나 때문에 나머지가 한 점으로 뭉치지 않도록
/// 중앙값에서 크게 벗어난 점은 제외한다 (지도를 움직이면 제외된 장소도 보인다).
GeoBounds? focusBounds(List<GeoPoint> points) {
  if (points.length < 3) return GeoBounds.around(points);
  double median(List<double> v) => (v..sort())[v.length ~/ 2];
  final mLat = median(points.map((p) => p.lat).toList());
  final mLng = median(points.map((p) => p.lng).toList());
  double dist(GeoPoint p) => math.max((p.lat - mLat).abs(), (p.lng - mLng).abs());
  final limit = math.max(0.03, median(points.map(dist).toList()) * 4);
  return GeoBounds.around(points.where((p) => dist(p) <= limit));
}

/// [AptMapController]가 명령을 전달하는 대상. 실제 지도 구현(AptMap 내부)만 구현한다.
abstract interface class AptMapCommands {
  void moveTo(GeoPoint target, {double zoom});
  void fitTo(List<GeoPoint> points);

  /// 내 위치 점(위치 오버레이). null이면 숨긴다. 카메라는 움직이지 않는다.
  void showLocationDot(GeoPoint? point);
}

/// 화면이 지도에 명령할 때 쓴다 (카메라 이동, 내 위치 점). 실제 SDK 지도가 붙어 있을 때만 동작하고,
/// 미리보기 지도(키 없음·인증 실패)면 false를 돌려준다. 지도가 준비되기 전 명령은 준비 후 적용된다.
class AptMapController {
  AptMapCommands? _target;

  /// AptMap 내부용: 실제 지도 구현을 연결/해제한다.
  void attach(AptMapCommands? target) => _target = target;

  bool moveTo(GeoPoint target, {double zoom = 15}) {
    _target?.moveTo(target, zoom: zoom);
    return _target != null;
  }

  /// 멀리 떨어진 장소는 빼고([focusBounds]) 나머지가 보이게 맞춘다.
  bool fitTo(List<GeoPoint> points) {
    if (points.isEmpty) return false;
    _target?.fitTo(points);
    return _target != null;
  }

  bool showLocationDot(GeoPoint? point) {
    _target?.showLocationDot(point);
    return _target != null;
  }
}

/// 공통 지도 위젯. 앱은 네이버 지도(확정, docs/02 §6), 웹은 OpenStreetMap([WebTileMap], 07 D29).
///
/// SDK가 초기화되어 있으면([NaverMapSdk.ready]) [NaverMapView], 아니면(클라이언트 ID 없음·
/// 인증 실패·테스트) [PreviewMap]으로 마커·경로 배치만 보여준다. 화면은 SDK 타입을 모른다.
class AptMap extends StatelessWidget {
  const AptMap({
    super.key,
    required this.markers,
    this.route = const [],
    this.onMarkerTap,
    this.onCameraIdle,
    this.selectedId,
    this.bottomPadding = 0,
    this.topPadding = 0,
    this.controller,
    this.fitMarkersOnLoad = true,
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

  /// 상단 검색바·칩에 가려지는 높이 (마커 배치 시 제외)
  final double topPadding;

  final AptMapController? controller;

  /// 처음 마커가 생기면 전체가 보이게 맞출지. false면 화면이 [controller]로 카메라를 정한다
  /// (저장됨 지도: 내 위치에서 시작).
  final bool fitMarkersOnLoad;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return WebTileMap(
        markers: markers,
        route: route,
        onMarkerTap: onMarkerTap,
        onCameraIdle: onCameraIdle,
        selectedId: selectedId,
        bottomPadding: bottomPadding,
        topPadding: topPadding,
        controller: controller,
        fitMarkersOnLoad: fitMarkersOnLoad,
      );
    }
    return ValueListenableBuilder<bool>(
      valueListenable: NaverMapSdk.ready,
      builder: (context, ready, _) => ready
          ? NaverMapView(
              markers: markers,
              route: route,
              onMarkerTap: onMarkerTap,
              onCameraIdle: onCameraIdle,
              selectedId: selectedId,
              bottomPadding: bottomPadding,
              topPadding: topPadding,
              controller: controller,
              fitMarkersOnLoad: fitMarkersOnLoad,
            )
          : PreviewMap(
              markers: markers,
              route: route,
              onMarkerTap: onMarkerTap,
              onCameraIdle: onCameraIdle,
              selectedId: selectedId,
              bottomPadding: bottomPadding,
              topPadding: topPadding,
            ),
    );
  }
}

