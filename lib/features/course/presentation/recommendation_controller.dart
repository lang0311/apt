import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/repositories.dart';
import '../../place/domain/place.dart';
import '../domain/course_draft.dart';
import '../domain/course_models.dart';
import 'course_draft_controller.dart';

/// 일정 편집 상태. 4단계 AI 추천과 저장한 코스 편집이 같이 쓴다.
/// 재추천 중에도 이전 결과(stops)를 유지한다 (깜빡임 방지).
class RecommendationState {
  const RecommendationState({
    this.stops = const [],
    this.recommendation,
    this.loading = false,
    this.error,
    this.basedOnPlaceIds,
    this.changedIds = const {},
    this.addedIds = const {},
  });

  /// 사용자가 편집 중인 현재 코스 (USER + AI)
  final List<CourseStop> stops;
  final Recommendation? recommendation;
  final bool loading;
  final Object? error;

  /// 이 결과를 만들 때의 사용자 장소 — 3단계에서 장소가 바뀌면 결과를 무효화한다
  final Set<String>? basedOnPlaceIds;

  /// 방금 다시 추천으로 바뀐 AI 장소 (주황 바탕)
  final Set<String> changedIds;

  /// 편집에서 방금 넣은 장소 ("새로 추가")
  final Set<String> addedIds;

  bool get hasResult => recommendation != null;

  /// 다시 추천 중에 뼈대로 보여 줄 자리 (AI 장소)
  Set<String> get loadingIds => loading && hasResult ? {for (final s in stops) if (s.isAi) s.place.id} : const {};

  RecommendationState copyWith({
    List<CourseStop>? stops,
    Recommendation? recommendation,
    bool? loading,
    Object? error,
    bool clearError = false,
    Set<String>? basedOnPlaceIds,
    Set<String>? changedIds,
    Set<String>? addedIds,
  }) =>
      RecommendationState(
        stops: stops ?? this.stops,
        recommendation: recommendation ?? this.recommendation,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        basedOnPlaceIds: basedOnPlaceIds ?? this.basedOnPlaceIds,
        changedIds: changedIds ?? this.changedIds,
        addedIds: addedIds ?? this.addedIds,
      );
}

/// 되돌리기용 직전 상태
class _Snapshot {
  const _Snapshot(this.state, this.draft, {this.blockedPlaceId});
  final RecommendationState state;
  final CourseDraft draft;

  /// 차단을 되돌릴 때 함께 해제할 장소
  final String? blockedPlaceId;
}

class RecommendationController extends Notifier<RecommendationState> {
  _Snapshot? _undo;

  /// 편집을 시작할 때의 일정 (바꾼 게 있는지 비교용)
  List<String> _initialIds = const [];

  @override
  RecommendationState build() => const RecommendationState();

  CourseDraftController get _draft => ref.read(courseDraftProvider.notifier);

  /// 시작할 때와 장소·순서가 달라졌는지 (닫기 전 확인용)
  bool get isDirty {
    final now = [for (final s in state.stops) s.place.id];
    if (now.length != _initialIds.length) return true;
    for (var i = 0; i < now.length; i++) {
      if (now[i] != _initialIds[i]) return true;
    }
    return false;
  }

  bool get canUndo => _undo != null;

  /// 화면 진입 시: 결과가 없거나 3단계에서 장소가 바뀌었으면 새로 추천받는다.
  /// 이전 결과가 무효화됐으면 true.
  Future<bool> syncWithDraft() async {
    final ids = ref.read(courseDraftProvider).placeIds;
    final stale = state.hasResult && !_sameSet(state.basedOnPlaceIds, ids);
    if (!state.hasResult || stale) {
      await _request(keepPrevious: false);
      _initialIds = [for (final s in state.stops) s.place.id];
    }
    return stale;
  }

  /// 저장한 코스 편집 시작 (코스 상세 → 편집). 초안과 일정을 코스 값으로 채운다.
  void startEditing(Course course) {
    _draft.loadFromCourse(course);
    _undo = null;
    _initialIds = [for (final s in course.stops) s.place.id];
    state = RecommendationState(
      stops: course.stops,
      recommendation: Recommendation(stops: course.stops),
      basedOnPlaceIds: ref.read(courseDraftProvider).placeIds,
    );
  }

  void _remember({String? blockedPlaceId}) =>
      _undo = _Snapshot(state, ref.read(courseDraftProvider), blockedPlaceId: blockedPlaceId);

  /// 다시 추천 — 내가 고른 장소는 두고 AI 장소 자리만 다시 채운다.
  /// 바뀐 AI 장소 수를 돌려준다(실패하면 null).
  Future<int?> recommendAgain({bool remember = true}) async {
    if (state.loading) return null;
    if (remember) _remember();
    final before = {for (final s in state.stops) if (s.isAi) s.place.id};
    _draft.update((d) => d.copyWith(recommendationRound: d.recommendationRound + 1));
    final ok = await _request(keepPrevious: true);
    if (!ok) return null;
    final changed = {for (final s in state.stops) if (s.isAi && !before.contains(s.place.id)) s.place.id};
    state = state.copyWith(changedIds: changed);
    return changed.length;
  }

  Future<bool> _request({required bool keepPrevious}) async {
    if (state.loading) return false;
    final previous = state;
    state = keepPrevious
        ? state.copyWith(loading: true, clearError: true)
        : RecommendationState(loading: true, stops: state.stops);
    final draft = ref.read(courseDraftProvider);
    try {
      final rec = await ref.read(courseRepositoryProvider).recommend(draft: draft, currentStops: previous.stops);
      state = RecommendationState(
        stops: rec.stops,
        recommendation: rec,
        basedOnPlaceIds: draft.placeIds,
        addedIds: previous.addedIds,
      );
      return true;
    } catch (e) {
      // 실패하면 이전 결과로 복구 + 재시도 가능
      state = previous.copyWith(loading: false, error: e);
      return false;
    }
  }

  /// 이 코스에서 빼기 (이번만). AI 장소는 이 코스를 다시 추천할 때도 나오지 않게 기록한다.
  void removeStop(CourseStop stop, {bool remember = true}) {
    if (remember) _remember();
    if (stop.isAi) {
      _draft.update((d) => d.reject(stop.place.id));
    } else {
      _draft.update((d) => d.removePlace(stop.place.id));
    }
    state = state.copyWith(
      stops: state.stops.where((s) => s.place.id != stop.place.id).toList(),
      basedOnPlaceIds: ref.read(courseDraftProvider).placeIds,
      changedIds: const {},
    );
  }

  /// 앞으로 추천하지 않기 (계정 단위 차단) + 이 코스에서 빼기. AI 장소만.
  Future<void> blockStop(CourseStop stop) async {
    assert(stop.isAi);
    await ref.read(courseRepositoryProvider).blockPlace(stop.place.id);
    _remember(blockedPlaceId: stop.place.id);
    removeStop(stop, remember: false);
  }

  /// AI 장소를 다른 곳으로 바꾸기 = 이번만 빼기 + 다시 추천
  Future<int?> replaceAi(CourseStop stop) async {
    _remember();
    removeStop(stop, remember: false);
    return recommendAgain(remember: false);
  }

  /// 직전 동작(빼기 · 차단 · 바꾸기 · 다시 추천)을 되돌린다.
  Future<void> undo() async {
    final snap = _undo;
    if (snap == null) return;
    _undo = null;
    if (snap.blockedPlaceId != null) {
      await ref.read(courseRepositoryProvider).unblockPlace(snap.blockedPlaceId!);
    }
    _draft.update((_) => snap.draft);
    state = snap.state.copyWith(loading: false, changedIds: const {});
  }

  void moveStop(int oldIndex, int newIndex) {
    final list = [...state.stops];
    if (newIndex > oldIndex) newIndex -= 1;
    list.insert(newIndex, list.removeAt(oldIndex));
    _syncUserOrder(list);
    state = state.copyWith(stops: list, changedIds: const {});
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
    state = state.copyWith(
      stops: list,
      basedOnPlaceIds: ref.read(courseDraftProvider).placeIds,
      addedIds: {...state.addedIds, for (final s in added) s.place.id},
      changedIds: const {},
    );
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
