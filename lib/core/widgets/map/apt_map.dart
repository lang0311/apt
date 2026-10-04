import 'package:flutter/material.dart';

import '../../models/geo_point.dart';
import 'map_pin.dart';
import 'naver_map_sdk.dart';
import 'naver_map_view.dart';
import 'preview_map.dart';

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

/// 화면이 지도에 명령할 때 쓴다 (내 위치 등). 실제 SDK 지도가 붙어 있을 때만 동작한다.
class AptMapController {
  VoidCallback? _showMyLocation;

  /// AptMap 내부용: 실제 지도 구현이 명령을 받을 함수를 연결/해제한다.
  void attach(VoidCallback? showMyLocation) => _showMyLocation = showMyLocation;

  /// 내 위치로 이동해 따라간다 (권한이 없으면 SDK가 요청한다).
  /// 실제 지도가 아니면(미리보기 — 키 없음/인증 실패) false.
  bool showMyLocation() {
    final f = _showMyLocation;
    if (f == null) return false;
    f();
    return true;
  }
}

/// 공통 지도 위젯. 네이버 지도(확정, docs/02 §6)를 감싼다.
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
    this.onLocationPermissionDenied,
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

  /// 위치 권한 거부. `forever`면 앱 설정에서 직접 허용해야 한다.
  final ValueChanged<bool>? onLocationPermissionDenied;

  @override
  Widget build(BuildContext context) {
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
              onLocationPermissionDenied: onLocationPermissionDenied,
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

