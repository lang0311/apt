import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/repositories.dart';
import '../../place/domain/place.dart';
import '../domain/course_models.dart';
import 'course_draft_controller.dart';

/// 4/4 AI 추천 루프 상태. 재추천 중에도 이전 결과(stops)를 유지한다 (깜빡임 방지).
class RecommendationState {
  const RecommendationState({
    this.stops = const [],
    this.recommendation,
    this.loading = false,
    this.error,
    this.basedOnPlaceIds,
  });

  /// 사용자가 편집 중인 현재 코스 (USER + AI)
  final List<CourseStop> stops;
  final Recommendation? recommendation;
  final bool loading;
  final Object? error;

  /// 이 결과를 만들 때의 사용자 장소 — 3/4에서 장소가 바뀌면 결과를 무효화한다
  final Set<String>? basedOnPlaceIds;

  bool get hasResult => recommendation != null;

  RecommendationState copyWith({
    List<CourseStop>? stops,
    Recommendation? recommendation,
    bool? loading,
    Object? error,
    bool clearError = false,
    Set<String>? basedOnPlaceIds,
  }) =>
      RecommendationState(
        stops: stops ?? this.stops,
        recommendation: recommendation ?? this.recommendation,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        basedOnPlaceIds: basedOnPlaceIds ?? this.basedOnPlaceIds,
      );
}

class RecommendationController extends Notifier<RecommendationState> {
  @override
  RecommendationState build() => const RecommendationState();

  CourseDraftController get _draft => ref.read(courseDraftProvider.notifier);

  /// 화면 진입 시: 결과가 없거나 3/4에서 장소가 바뀌었으면 새로 추천받는다.
  /// 이전 결과가 무효화됐으면 true.
  Future<bool> syncWithDraft() async {
    final ids = ref.read(courseDraftProvider).placeIds;
    final stale = state.hasResult && !_sameSet(state.basedOnPlaceIds, ids);
    if (!state.hasResult || stale) await _request(keepPrevious: false);
    return stale;
  }

  /// "다른 추천" — 현재 코스(편집 결과)를 기준으로 재추천
  Future<void> recommendAgain() async {
    _draft.update((d) => d.copyWith(recommendationRound: d.recommendationRound + 1));
    await _request(keepPrevious: true);
  }

  Future<void> _request({required bool keepPrevious}) async {
    if (state.loading) return;
    state = keepPrevious
        ? state.copyWith(loading: true, clearError: true)
        : RecommendationState(loading: true, stops: state.stops);
    final draft = ref.read(courseDraftProvider);
    try {
      final rec = await ref.read(courseRepositoryProvider).recommend(draft: draft, currentStops: state.stops);
      state = RecommendationState(stops: rec.stops, recommendation: rec, basedOnPlaceIds: draft.placeIds);
    } catch (e) {
      // 실패하면 이전 결과로 복구 + 재시도 가능
      state = state.copyWith(loading: false, error: e);
    }
  }

  /// 코스에서 빼기. AI 추천을 빼면 다음 추천에서 제외되도록 기록한다.
  void removeStop(CourseStop stop) {
    if (stop.isAi) {
      _draft.update((d) => d.reject(stop.place.id));
    } else {
      _draft.update((d) => d.removePlace(stop.place.id));
    }
    state = state.copyWith(
      stops: state.stops.where((s) => s.place.id != stop.place.id).toList(),
      basedOnPlaceIds: ref.read(courseDraftProvider).placeIds,
    );
  }

  /// AI 추천 장소를 다른 곳으로 바꾸기 = 제외 + 재추천
  Future<void> replaceAi(CourseStop stop) async {
    removeStop(stop);
    await recommendAgain();
  }

  void moveStop(int oldIndex, int newIndex) {
    final list = [...state.stops];
    if (newIndex > oldIndex) newIndex -= 1;
    list.insert(newIndex, list.removeAt(oldIndex));
    _syncUserOrder(list);
    state = state.copyWith(stops: list);
  }

  void addPlaces(List<Place> places) {
    final existing = state.stops.map((s) => s.place.id).toSet();
    final added = [
      for (final p in places)
        if (!existing.contains(p.id)) CourseStop(place: p, source: PlaceSource.user),
    ];
    final list = [...state.stops, ...added];
    _draft.update((d) => d.addPlaces(added.map((s) => s.place)));
    _syncUserOrder(list);
    state = state.copyWith(stops: list, basedOnPlaceIds: ref.read(courseDraftProvider).placeIds);
  }

  /// 코스의 사용자 장소 순서를 초안에도 반영
  void _syncUserOrder(List<CourseStop> stops) {
    final order = [for (final s in stops) if (!s.isAi) s.place];
    _draft.update((d) => d.copyWith(places: order));
  }

  static bool _sameSet(Set<String>? a, Set<String> b) => a != null && a.length == b.length && a.containsAll(b);
}

final recommendationProvider = NotifierProvider<RecommendationController, RecommendationState>(
  RecommendationController.new,
);
