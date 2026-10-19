import 'dart:math' as math;

/// 위경도. 지도 SDK 타입에 의존하지 않도록 앱 자체 모델을 쓴다.
class GeoPoint {
  const GeoPoint(this.lat, this.lng);
  final double lat;
  final double lng;

  /// 직선거리(m, haversine). 도보 시간·경로 거리는 서버 몫이다.
  double distanceTo(GeoPoint other) {
    const earthRadius = 6371000.0;
    double rad(double deg) => deg * math.pi / 180;
    final dLat = rad(other.lat - lat);
    final dLng = rad(other.lng - lng);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(lat)) * math.cos(rad(other.lat)) * math.pow(math.sin(dLng / 2), 2);
    return 2 * earthRadius * math.asin(math.sqrt(a));
  }

  @override
  bool operator ==(Object other) => other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);
}

/// 지도 영역(bbox). 저장 지도는 보이는 영역을 덮는 원(중심 + 반경)으로 nearby를 조회한다.
class GeoBounds {
  const GeoBounds({required this.southWest, required this.northEast});
  final GeoPoint southWest;
  final GeoPoint northEast;

  GeoPoint get center => GeoPoint((southWest.lat + northEast.lat) / 2, (southWest.lng + northEast.lng) / 2);

  /// 중심에서 모서리까지 — 이 반경의 원이 영역 전체를 덮는다.
  double get radiusMeters => center.distanceTo(northEast);

  @override
  bool operator ==(Object other) =>
      other is GeoBounds && other.southWest == southWest && other.northEast == northEast;

  @override
  int get hashCode => Object.hash(southWest, northEast);

  bool contains(GeoPoint p) =>
      p.lat >= southWest.lat && p.lat <= northEast.lat && p.lng >= southWest.lng && p.lng <= northEast.lng;

  static GeoBounds? around(Iterable<GeoPoint> points) {
    if (points.isEmpty) return null;
    var minLat = double.infinity, minLng = double.infinity;
    var maxLat = -double.infinity, maxLng = -double.infinity;
    for (final p in points) {
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lng < minLng) minLng = p.lng;
      if (p.lng > maxLng) maxLng = p.lng;
    }
    return GeoBounds(southWest: GeoPoint(minLat, minLng), northEast: GeoPoint(maxLat, maxLng));
  }
}
