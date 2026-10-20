import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/repositories.dart';
import '../../../core/location/location_service.dart';
import '../../../core/models/geo_point.dart';
import '../../extraction/presentation/extraction_providers.dart';
import '../../home/presentation/home_providers.dart';
import '../../place/domain/place.dart';
import '../domain/saved_models.dart';

final savedSummaryProvider = FutureProvider.autoDispose<SavedSummary>(
  (ref) => ref.watch(savedRepositoryProvider).fetchSummary(),
);

final savedPlacesProvider = FutureProvider.autoDispose.family<List<SavedPlaceItem>, SavedPlaceQuery>(
  (ref, query) => ref.watch(savedRepositoryProvider).fetchSavedPlaces(query),
);

class MapQuery {
  const MapQuery(this.bounds, this.query);
  final GeoBounds bounds;
  final SavedPlaceQuery query;

  @override
  bool operator ==(Object other) => other is MapQuery && other.bounds == bounds && other.query == query;

  @override
  int get hashCode => Object.hash(bounds, query);
}

/// 지도에 보이는 저장 장소. 보이는 영역을 덮는 원(중심 → 모서리)으로 nearby를 부르고,
/// 원 안이지만 화면 밖인 장소는 뺀다. 거리는 서버가 주지 않으므로 내 위치에서 직선거리로 계산한다.
final savedPlacesInBoundsProvider = FutureProvider.autoDispose.family<List<SavedPlaceItem>, MapQuery>((ref, q) async {
  final b = q.bounds;
  final me = ref.watch(myLocationProvider)?.point;
  final items = await ref.watch(savedRepositoryProvider).fetchSavedPlacesNearby(b.center, b.radiusMeters.ceil(), q.query);
  final visible = [
    for (final i in items)
      if (i.place.location != null && b.contains(i.place.location!))
        me == null ? i : SavedPlaceItem(place: i.place, distanceMeters: me.distanceTo(i.place.location!).round()),
  ];
  if (q.query.sort == SavedSort.nearest && me != null) {
    visible.sort((a, c) => a.distanceMeters!.compareTo(c.distanceMeters!));
  }
  return visible;
});

/// 저장됨 카테고리 필터(대분류 키, null=전체). 탭을 바꾸거나 상세에 다녀와도 유지하고, 앱을 다시 켜면 풀린다.
final savedCategoryFilterProvider = NotifierProvider<SavedCategoryFilter, String?>(SavedCategoryFilter.new);

class SavedCategoryFilter extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? categoryKey) => state = categoryKey;
}

final collectionsProvider = FutureProvider.autoDispose<List<PlaceCollection>>(
  (ref) => ref.watch(savedRepositoryProvider).fetchCollections(),
);

final collectionProvider = FutureProvider.autoDispose.family<PlaceCollection, String>(
  (ref, id) => ref.watch(savedRepositoryProvider).fetchCollection(id),
);

final placeDetailProvider = FutureProvider.autoDispose.family<PlaceDetail, String>(
  (ref, id) => ref.watch(placeRepositoryProvider).fetchPlace(id),
);

/// 저장 관련 변경 후 영향을 받는 조회를 새로 고친다.
void invalidateSavedData(WidgetRef ref) {
  ref.invalidate(savedSummaryProvider);
  ref.invalidate(savedPlacesProvider);
  ref.invalidate(savedPlacesInBoundsProvider);
  ref.invalidate(collectionsProvider);
  ref.invalidate(collectionProvider);
  ref.invalidate(placeDetailProvider);
  // 저장 수가 바뀌면 홈 통계/최근 추출의 저장 상태도 바뀐다
  ref.invalidate(homeStatsProvider);
  ref.invalidate(recentExtractionsProvider);
  ref.invalidate(trendingPlacesProvider);
}
