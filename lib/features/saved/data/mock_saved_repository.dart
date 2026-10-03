import '../../../core/error/app_failure.dart';
import '../../../core/models/geo_point.dart';
import '../../../dev/mock/mock_fixtures.dart';
import '../../../dev/mock/mock_store.dart';
import '../domain/saved_models.dart';
import '../domain/saved_repository.dart';

class MockSavedRepository implements SavedRepository {
  MockSavedRepository(this._store);
  final MockStore _store;

  @override
  Future<SavedSummary> fetchSummary() => _store.behavior.query(
        () {
          final saved = _store.savedPlaces;
          return SavedSummary(
            totalCount: saved.length,
            categories: [
              for (final e in MockFixtures.categories.entries)
                PlaceCategory(key: e.key, label: e.value, count: saved.where((p) => p.categoryKey == e.key).length),
            ],
          );
        },
        empty: () => SavedSummary(
          totalCount: 0,
          categories: [for (final e in MockFixtures.categories.entries) PlaceCategory(key: e.key, label: e.value, count: 0)],
        ),
      );

  List<SavedPlaceItem> _filter(SavedPlaceQuery q) {
    var places = q.collectionId == null
        ? _store.savedPlaces
        : [for (final id in _store.members[q.collectionId] ?? const <String>[]) _store.placeWithSaved(id)];
    if (q.categoryKey != null) places = places.where((p) => p.categoryKey == q.categoryKey).toList();
    final k = q.keyword?.trim();
    if (k != null && k.isNotEmpty) {
      places = places.where((p) => p.name.contains(k) || p.address.contains(k) || p.keywords.any((w) => w.contains(k))).toList();
    }
    final items = [
      for (var i = 0; i < places.length; i++)
        SavedPlaceItem(place: places[i], distanceMeters: 350 + i * 420, walkMinutes: 5 + i * 6),
    ];
    switch (q.sort) {
      case SavedSort.nearest:
        items.sort((a, b) => a.distanceMeters!.compareTo(b.distanceMeters!));
      case SavedSort.rating:
        items.sort((a, b) => (b.place.rating ?? 0).compareTo(a.place.rating ?? 0));
      case SavedSort.recent:
        break;
    }
    return items;
  }

  @override
  Future<List<SavedPlaceItem>> fetchSavedPlaces(SavedPlaceQuery query) =>
      _store.behavior.query(() => _filter(query), empty: () => const []);

  @override
  Future<List<SavedPlaceItem>> fetchSavedPlacesInBounds(GeoBounds bounds, SavedPlaceQuery query) =>
      _store.behavior.query(
        () => _filter(query).where((i) => i.place.location != null && bounds.contains(i.place.location!)).toList(),
        empty: () => const [],
        latency: const Duration(milliseconds: 300),
      );

  @override
  Future<List<PlaceCollection>> fetchCollections() => _store.behavior.query(
        () => [for (final id in _store.collections.keys) _store.collectionView(id)],
        empty: () => const [],
      );

  @override
  Future<PlaceCollection> fetchCollection(String collectionId) => _store.behavior.query(() {
        if (!_store.collections.containsKey(collectionId)) throw const NotFoundFailure();
        return _store.collectionView(collectionId);
      });

  @override
  Future<PlaceCollection> createCollection(String name) => _store.behavior.mutate(() {
        final trimmed = name.trim();
        if (trimmed.isEmpty) throw const ValidationFailure('보관함 이름을 입력해주세요.');
        if (_store.collections.values.any((c) => c.name == trimmed)) {
          throw const ValidationFailure('같은 이름의 보관함이 있어요.');
        }
        final id = _store.nextId('c');
        _store.collections[id] = PlaceCollection(id: id, name: trimmed, placeCount: 0, updatedAt: DateTime.now(), createdAt: DateTime.now());
        _store.members[id] = [];
        return _store.collectionView(id);
      });

  @override
  Future<void> savePlaces({required List<String> placeIds, required List<String> collectionIds}) =>
      _store.behavior.mutate(() {
        _store.savedIds.addAll(placeIds);
        for (final cid in collectionIds) {
          final list = _store.members[cid]!;
          for (final pid in placeIds) {
            if (!list.contains(pid)) list.add(pid);
          }
          _store.touchCollection(cid);
        }
      });

  @override
  Future<void> setPlaceCollections({required String placeId, required List<String> collectionIds}) =>
      _store.behavior.mutate(() {
        _store.savedIds.add(placeId);
        for (final entry in _store.members.entries) {
          final should = collectionIds.contains(entry.key);
          final has = entry.value.contains(placeId);
          if (should && !has) entry.value.add(placeId);
          if (!should && has) entry.value.remove(placeId);
          if (should != has) _store.touchCollection(entry.key);
        }
      });

  @override
  Future<List<String>> fetchPlaceCollectionIds(String placeId) => _store.behavior.query(
        () => [for (final e in _store.members.entries) if (e.value.contains(placeId)) e.key],
      );

  @override
  Future<void> addPlacesToCollection({required String collectionId, required List<String> placeIds}) =>
      savePlaces(placeIds: placeIds, collectionIds: [collectionId]);
}
