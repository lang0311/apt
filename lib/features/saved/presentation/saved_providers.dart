import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/repositories.dart';
import '../../../app/di/data_source.dart';
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
final savedPlacesInBoundsProvider = FutureProvider.autoDispose.family<List<SavedPlaceItem>, MapQuery>((ref, mapQuery) async {
  final bounds = mapQuery.bounds;
  final me = ref.watch(myLocationProvider)?.point;
  final items = await ref
      .watch(savedRepositoryProvider)
      .fetchSavedPlacesNearby(bounds.center, bounds.radiusMeters.ceil(), mapQuery.query);

  final visible = [
    for (final item in items)
      if (item.place.location != null && bounds.contains(item.place.location!)) item,
  ];
  return withDistanceFrom(me, visible, mapQuery.query.sort);
});

/// 내 위치에서 직선거리를 붙이고, 가까운 순이면 정렬한다. 위치를 모르면 거리 없이 그대로.
/// 서버는 거리를 주지 않고 거리순 정렬도 하지 않는다. 도보 시간은 서버가 줄 때만 표시한다(NEEDS BACKEND).
List<SavedPlaceItem> withDistanceFrom(GeoPoint? me, List<SavedPlaceItem> items, SavedSort sort) {
  if (me == null) return items;
  final measured = [
    for (final item in items)
      item.place.location == null
          ? item
          : SavedPlaceItem(
              place: item.place,
              distanceMeters: me.distanceTo(item.place.location!).round(),
              walkMinutes: item.walkMinutes,
            ),
  ];
  if (sort == SavedSort.nearest) {
    // 위치가 없는 장소는 맨 뒤
    measured.sort((a, b) => (a.distanceMeters ?? 1 << 30).compareTo(b.distanceMeters ?? 1 << 30));
  }
  return measured;
}

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

/// 팀 서버에는 보관함이 아직 없다. 서버 데이터일 때 보관함 버튼은 그대로 두고 누르면 준비 중으로 안내한다. NEEDS BACKEND
final collectionsSupportedProvider = Provider<bool>((ref) => ref.watch(dataSourceProvider) != DataSource.server);

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
