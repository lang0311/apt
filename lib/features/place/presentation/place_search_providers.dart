import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/repositories.dart';
import '../../../core/models/geo_point.dart';
import '../domain/place.dart';
import '../domain/place_search_repository.dart';

/// 지도 검색 조건. [near]가 있으면 '현재 지도에서 검색하기'.
/// [category]가 있으면 검색어 없이 [near] 주변을 그 업종으로 찾는다 (10번 칩).
class PlaceSearchQuery {
  const PlaceSearchQuery(this.text, {this.near, this.category});
  const PlaceSearchQuery.category(PlaceSearchCategory this.category, {required GeoPoint this.near}) : text = '';
  final String text;
  final GeoPoint? near;
  final PlaceSearchCategory? category;

  @override
  bool operator ==(Object other) =>
      other is PlaceSearchQuery && other.text == text && other.category == category && other.near?.lat == near?.lat && other.near?.lng == near?.lng;

  @override
  int get hashCode => Object.hash(text, category, near?.lat, near?.lng);
}

final placeSearchProvider = FutureProvider.autoDispose.family<List<Place>, PlaceSearchQuery>(
  (ref, q) => ref.watch(placeSearchRepositoryProvider).search(q.text, near: q.near, category: q.category),
);
