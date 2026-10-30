import 'package:apt/app/di/repositories.dart';
import 'package:apt/core/location/location_service.dart';
import 'package:apt/core/models/geo_point.dart';
import 'package:apt/features/place/domain/place.dart';
import 'package:apt/features/saved/domain/saved_models.dart';
import 'package:apt/features/saved/domain/saved_repository.dart';
import 'package:apt/features/saved/presentation/saved_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Place _p(String id, GeoPoint at) =>
    Place(id: id, name: id, address: '', categoryKey: 'cafe', categoryLabel: '카페', location: at);

/// nearby 응답을 흉내 낸다: 반경 안의 장소를 거리 없이 돌려준다 (서버가 거리를 주지 않는다는 가정).
class _FakeSavedRepository implements SavedRepository {
  _FakeSavedRepository(this.places);
  final List<Place> places;
  GeoPoint? lastCenter;
  int? lastRadius;

  @override
  Future<List<SavedPlaceItem>> fetchSavedPlacesNearby(GeoPoint center, int radiusMeters, SavedPlaceQuery query) async {
    lastCenter = center;
    lastRadius = radiusMeters;
    return [
      for (final p in places)
        if (center.distanceTo(p.location!) <= radiusMeters) SavedPlaceItem(place: p),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeLocationService implements LocationService {
  _FakeLocationService(this.result);
  final LocationResult result;

  @override
  Future<LocationResult> current({bool request = true}) async => result;

  @override
  Future<void> openSettings(LocationStatus status) async {}
}

void main() {
  // 화면 영역: 성수동 일대 (약 2.2km × 1.8km)
  const bounds = GeoBounds(southWest: GeoPoint(37.535, 127.045), northEast: GeoPoint(37.555, 127.065));
  final near = _p('near', const GeoPoint(37.5450, 127.0560));
  final far = _p('far', const GeoPoint(37.5370, 127.0630));
  // 원(중심 → 모서리) 안이지만 사각형 밖: 위쪽 가장자리 바로 너머
  final outside = _p('outside', const GeoPoint(37.5560, 127.0550));
  final busan = _p('busan', const GeoPoint(35.1587, 129.1604));

  ProviderContainer container(LocationResult location) {
    final c = ProviderContainer(overrides: [
      savedRepositoryProvider.overrideWithValue(_FakeSavedRepository([far, near, outside, busan])),
      locationServiceProvider.overrideWithValue(_FakeLocationService(location)),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('보이는 영역을 덮는 원으로 nearby를 부르고, 화면 밖 장소는 뺀다', () async {
    final c = container(const LocationResult(LocationStatus.denied));
    final repo = c.read(savedRepositoryProvider) as _FakeSavedRepository;

    final items = await c.read(savedPlacesInBoundsProvider(const MapQuery(bounds, SavedPlaceQuery())).future);

    expect(repo.lastCenter, bounds.center);
    expect(repo.lastRadius, bounds.radiusMeters.ceil());
    expect(items.map((i) => i.place.id), unorderedEquals(['near', 'far']));
    // 위치를 모르면 거리를 표시하지 않는다
    expect(items.every((i) => i.distanceMeters == null), isTrue);
  });

  test('내 위치를 알면 직선거리를 계산하고, 가까운 순이면 정렬한다', () async {
    const me = GeoPoint(37.5446, 127.0557);
    final c = container(const LocationResult(LocationStatus.granted, me));
    await c.read(myLocationProvider.notifier).locate();

    final items = await c.read(
      savedPlacesInBoundsProvider(const MapQuery(bounds, SavedPlaceQuery(sort: SavedSort.nearest))).future,
    );

    expect(items.map((i) => i.place.id), ['near', 'far']);
    expect(items.first.distanceMeters, me.distanceTo(near.location!).round());
  });

  test('일시적으로 위치를 못 얻으면 직전 위치를 유지하고, 권한이 없어지면 지운다', () async {
    const me = GeoPoint(37.5446, 127.0557);
    var next = const LocationResult(LocationStatus.granted, me);
    final c = ProviderContainer(overrides: [
      locationServiceProvider.overrideWith((ref) => _FakeLocationService(next)),
    ]);
    addTearDown(c.dispose);
    final notifier = c.read(myLocationProvider.notifier);

    await notifier.locate();
    expect(c.read(myLocationProvider)?.point, me);

    c.invalidate(locationServiceProvider);
    next = const LocationResult(LocationStatus.unavailable);
    await notifier.locate();
    expect(c.read(myLocationProvider)?.point, me);

    c.invalidate(locationServiceProvider);
    next = const LocationResult(LocationStatus.denied);
    await notifier.locate();
    expect(c.read(myLocationProvider)?.point, isNull);
  });
  test('자동 검색을 끈 전체 목록도 같은 규칙: 위치를 모르면 거리 없음, 알면 직선거리 + 가까운 순', () {
    const me = GeoPoint(37.5446, 127.0557);
    final items = [SavedPlaceItem(place: far), SavedPlaceItem(place: near)];

    expect(withDistanceFrom(null, items, SavedSort.nearest).every((i) => i.distanceMeters == null), isTrue);

    final sorted = withDistanceFrom(me, items, SavedSort.nearest);
    expect(sorted.map((i) => i.place.id), ['near', 'far']);
    expect(sorted.first.distanceMeters, me.distanceTo(near.location!).round());
    // 최근 순이면 순서는 그대로
    expect(withDistanceFrom(me, items, SavedSort.recent).map((i) => i.place.id), ['far', 'near']);
  });
}
