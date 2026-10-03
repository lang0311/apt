/// 위경도. 지도 SDK 타입에 의존하지 않도록 앱 자체 모델을 쓴다.
class GeoPoint {
  const GeoPoint(this.lat, this.lng);
  final double lat;
  final double lng;

  @override
  bool operator ==(Object other) => other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);
}

/// 지도 영역(bbox). 저장 지도는 viewport 기반으로 조회한다.
class GeoBounds {
  const GeoBounds({required this.southWest, required this.northEast});
  final GeoPoint southWest;
  final GeoPoint northEast;

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
