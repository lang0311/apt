import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/repositories.dart';
import '../../../core/models/geo_point.dart';
import '../domain/place.dart';

/// 지도 검색 조건. [near]가 있으면 '현재 지도에서 검색하기'.
class PlaceSearchQuery {
  const PlaceSearchQuery(this.text, {this.near});
  final String text;
  final GeoPoint? near;

  @override
  bool operator ==(Object other) =>
      other is PlaceSearchQuery && other.text == text && other.near?.lat == near?.lat && other.near?.lng == near?.lng;

  @override
  int get hashCode => Object.hash(text, near?.lat, near?.lng);
}

final placeSearchProvider = FutureProvider.autoDispose.family<List<Place>, PlaceSearchQuery>(
  (ref, q) => ref.watch(placeSearchRepositoryProvider).search(q.text, near: q.near),
);
