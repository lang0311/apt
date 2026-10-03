import 'package:flutter/material.dart';

import '../../place/domain/place.dart';
import 'course_models.dart';

/// 코스 만들기 위저드 전 단계가 공유하는 초안. (docs/02 §7)
/// 정보(1) → 장소(2) → 동행(3) → AI 추천(4) ⇄ [장소 수정 → 재추천]
class CourseDraft {
  const CourseDraft({
    this.courseId,
    this.name = '',
    this.date,
    this.startTime,
    this.moodKeys = const {},
    this.places = const [],
    this.companion = Companion.solo,
    this.partyId,
    this.rejectedPlaceIds = const {},
    this.recommendationRound = 0,
  });

  /// 완성된 코스를 다시 편집하는 경우(코스 상세 → 다른 추천 받기) 원본 코스 ID
  final String? courseId;
  final String name;
  final DateTime? date;
  final TimeOfDay? startTime;
  final Set<String> moodKeys;

  /// 사용자가 고른 장소(USER), 순서대로
  final List<Place> places;
  final Companion companion;
  final String? partyId;

  /// 사용자가 빼거나 교체한 AI 추천 — 재추천 시 제외 요청용 (서버 지원 여부 NEEDS BACKEND)
  final Set<String> rejectedPlaceIds;
  final int recommendationRound;

  bool get isEditingExisting => courseId != null;
  bool get infoComplete => name.trim().isNotEmpty && date != null && startTime != null;
  bool get hasPlaces => places.isNotEmpty;
  Set<String> get placeIds => places.map((p) => p.id).toSet();

  CourseDraft copyWith({
    String? name,
    DateTime? date,
    TimeOfDay? startTime,
    Set<String>? moodKeys,
    List<Place>? places,
    Companion? companion,
    String? partyId,
    bool clearPartyId = false,
    Set<String>? rejectedPlaceIds,
    int? recommendationRound,
  }) {
    return CourseDraft(
      courseId: courseId,
      name: name ?? this.name,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      moodKeys: moodKeys ?? this.moodKeys,
      places: places ?? this.places,
      companion: companion ?? this.companion,
      partyId: clearPartyId ? null : (partyId ?? this.partyId),
      rejectedPlaceIds: rejectedPlaceIds ?? this.rejectedPlaceIds,
      recommendationRound: recommendationRound ?? this.recommendationRound,
    );
  }

  CourseDraft toggleMood(String key) {
    final next = {...moodKeys};
    next.contains(key) ? next.remove(key) : next.add(key);
    return copyWith(moodKeys: next);
  }

  /// 중복 없이 뒤에 추가
  CourseDraft addPlaces(Iterable<Place> added) {
    final ids = placeIds;
    return copyWith(places: [...places, ...added.where((p) => !ids.contains(p.id))]);
  }

  CourseDraft removePlace(String placeId) =>
      copyWith(places: places.where((p) => p.id != placeId).toList());

  /// ReorderableListView 규칙(newIndex는 제거 전 기준)을 따른다.
  CourseDraft reorder(int oldIndex, int newIndex) {
    final list = [...places];
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    return copyWith(places: list);
  }

  CourseDraft reject(String placeId) => copyWith(rejectedPlaceIds: {...rejectedPlaceIds, placeId});

  static CourseDraft fromCourse(Course course) => CourseDraft(
        courseId: course.id,
        name: course.title,
        date: course.date,
        startTime: course.startTime,
        moodKeys: course.moodKeys,
        places: course.stops.where((s) => !s.isAi).map((s) => s.place).toList(),
        companion: course.isParty ? Companion.party : Companion.solo,
        partyId: course.partyId,
      );
}
