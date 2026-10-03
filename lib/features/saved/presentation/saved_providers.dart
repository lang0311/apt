import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/repositories.dart';
import '../../../core/models/geo_point.dart';
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

final savedPlacesInBoundsProvider = FutureProvider.autoDispose.family<List<SavedPlaceItem>, MapQuery>(
  (ref, q) => ref.watch(savedRepositoryProvider).fetchSavedPlacesInBounds(q.bounds, q.query),
);

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
}
