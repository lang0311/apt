import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import '../../../core/utils/formatters.dart';
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

/// 저장됨의 AI 추천 탭: 코스를 저장할 때 AI 추천으로 들어온 장소 (07 D44)
final aiSavedPlacesProvider = FutureProvider.autoDispose<List<SavedPlaceItem>>(
  (ref) => ref.watch(savedRepositoryProvider).fetchAiSavedPlaces(),
);

/// AI 추천 장소의 카테고리별 개수 (AI 추천 탭 · 코스 장소 고르기의 필터, 07 D47).
/// 서버 요약(`/mobile/summary`)은 이 장소들을 따로 나누지 않아서, 이미 받은 목록으로 앱이 센다(D44와 같은 예외).
/// NEEDS BACKEND: 요약이 `action_type`별로 나뉘면 서버 값을 쓴다.
final aiSavedSummaryProvider = FutureProvider.autoDispose<SavedSummary>(
  (ref) async => summarizeByCategory([for (final item in await ref.watch(aiSavedPlacesProvider.future)) item.place]),
);

/// AI 추천 탭의 카테고리 필터 (카테고리 탭의 필터와 따로 기억한다)
final aiCategoryFilterProvider = NotifierProvider<SavedCategoryFilter, Set<String>>(SavedCategoryFilter.new);

/// 필터에 쓰는 장소의 카테고리 키. 서버 요약과 같게 업종이 없으면 '기타'
String categoryKeyOfPlace(Place place) => place.categoryKey.isEmpty ? '기타' : place.categoryKey;

/// 장소 목록을 카테고리별로 센다 (처음 나온 순서)
SavedSummary summarizeByCategory(Iterable<Place> places) {
  final counts = <String, int>{};
  for (final place in places) {
    final key = categoryKeyOfPlace(place);
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return SavedSummary(
    totalCount: counts.values.fold(0, (sum, n) => sum + n),
    categories: [
      for (final MapEntry(:key, :value) in counts.entries)
        PlaceCategory(key: key, label: categoryShortLabel(key), count: value),
    ],
  );
}

/// 두 요약을 더한다 (코스 장소 고르기에서 직접 저장 + 추천받은 곳). 같은 카테고리는 개수를 합친다
SavedSummary mergeSummaries(SavedSummary a, SavedSummary b) {
  final merged = <String, PlaceCategory>{};
  for (final c in [...a.categories, ...b.categories]) {
    final old = merged[c.key];
    merged[c.key] = old == null ? c : PlaceCategory(key: c.key, label: old.label, count: old.count + c.count);
  }
  return SavedSummary(totalCount: a.totalCount + b.totalCount, categories: merged.values.toList());
}

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

/// 저장됨 카테고리 필터(고른 카테고리 키들, 비면 전체 — 여러 개 고를 수 있다, 07 D48).
/// 탭을 바꾸거나 상세에 다녀와도 유지하고, 앱을 다시 켜면 풀린다.
final savedCategoryFilterProvider = NotifierProvider<SavedCategoryFilter, Set<String>>(SavedCategoryFilter.new);

/// 저장됨 지역별 보기의 지역 필터 (구 · 시 이름, 여러 개). 비면 전체
final savedRegionFilterProvider = NotifierProvider<SavedCategoryFilter, Set<String>>(SavedCategoryFilter.new);

/// 저장됨 전체 탭의 보기 방식. 앱을 켜 둔 동안 유지된다
enum SavedView {
  region('지역별'),
  category('업종별'),
  recent('최근 저장한 순'),
  name('이름순');

  const SavedView(this.label);
  final String label;
}

class SavedViewController extends Notifier<SavedView> {
  @override
  SavedView build() => SavedView.region;

  void set(SavedView view) => state = view;
}

final savedViewProvider = NotifierProvider<SavedViewController, SavedView>(SavedViewController.new);

class SavedCategoryFilter extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void select(Set<String> keys) => state = Set.unmodifiable(keys);

  void clear() => state = const {};
}

/// 고른 카테고리에 드는지 (비어 있으면 모두)
bool matchesCategories(Place place, Set<String> keys) => keys.isEmpty || keys.contains(categoryKeyOfPlace(place));

/// 고른 카테고리를 칩 한 줄로: 하나면 그 이름, 둘 이상이면 '첫째 외 n'. 요약 순서로 첫째를 정한다.
/// 요약에서 사라진 키도 이름은 키의 마지막 단계로 보여 준다(걸린 필터를 풀 수 있게).
String categoryFilterLabel(SavedSummary? summary, Set<String> keys) {
  if (keys.isEmpty) return '';
  final ordered = [
    for (final c in summary?.categories ?? const <PlaceCategory>[])
      if (keys.contains(c.key)) c.label,
    for (final k in keys)
      if (!(summary?.categories.any((c) => c.key == k) ?? false)) categoryShortLabel(k),
  ];
  return ordered.length == 1 ? ordered.first : '${ordered.first} 외 ${ordered.length - 1}';
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
void invalidateSavedData(WidgetRef ref) => _savedData.forEach(ref.invalidate);

/// 화면이 사라진 뒤에도(스낵바의 되돌리기 등) 쓸 수 있게 컨테이너로 새로 고친다.
void invalidateSavedDataIn(ProviderContainer container) => _savedData.forEach(container.invalidate);

final _savedData = <ProviderOrFamily>[
  savedSummaryProvider,
  savedPlacesProvider,
  aiSavedPlacesProvider,
  savedPlacesInBoundsProvider,
  collectionsProvider,
  collectionProvider,
  placeDetailProvider,
  // 저장 수가 바뀌면 홈 통계/최근 추출의 저장 상태도 바뀐다
  homeStatsProvider,
  recentExtractionsProvider,
  trendingPlacesProvider,
];
