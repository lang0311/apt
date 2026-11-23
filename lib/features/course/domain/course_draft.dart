import 'package:flutter/material.dart';

import '../../place/domain/place.dart';
import 'course_models.dart';

/// 코스 만들기 위저드 전 단계가 공유하는 초안. (docs/02 §7)
/// 정보(1) → 동행(2) → 장소(3) → AI 추천(4) ⇄ [장소 수정 → 재추천]
class CourseDraft {
  const CourseDraft({
    this.name = '',
    this.date,
    this.startTime,
    this.moodKeys = const {},
    this.places = const [],
    this.companion = Companion.solo,
    this.partyId,
    this.rejectedPlaceIds = const {},
    this.recommendationRound = 0,
    this.placeCount,
  });

  final String name;
  final DateTime? date;
  final TimeOfDay? startTime;
  final Set<String> moodKeys;

  /// 사용자가 고른 장소(USER), 순서대로
  final List<Place> places;
  final Companion companion;
  final String? partyId;

  /// 이번 코스에서만 뺀 장소(바꾸기·빼기·편집 X) — 이 코스를 다시 추천할 때 제외 요청용.
  /// 다른 코스에서는 다시 나올 수 있다. 계정 단위 차단은 [CourseRepository.blockPlace]. (서버 지원 여부 NEEDS BACKEND)
  final Set<String> rejectedPlaceIds;
  final int recommendationRound;

  /// 코스 전체 장소 수 (11번, 3/4 −/+). null이면 기본값 고른 수 + 3 (서버는 1~6곳, 고른 수보다 적으면 422)
  final int? placeCount;

  /// 서버가 받는 코스 장소 수 범위
  static const maxPlaceCount = 6;

  /// 고른 수 이상, 6 이하로 맞춘 코스 장소 수
  int get coursePlaceCount {
    final floor = places.length.clamp(1, maxPlaceCount);
    return (placeCount ?? places.length + 3).clamp(floor, maxPlaceCount);
  }

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
    int? placeCount,
  }) {
    return CourseDraft(
      name: name ?? this.name,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      moodKeys: moodKeys ?? this.moodKeys,
      places: places ?? this.places,
      companion: companion ?? this.companion,
      partyId: clearPartyId ? null : (partyId ?? this.partyId),
      rejectedPlaceIds: rejectedPlaceIds ?? this.rejectedPlaceIds,
      recommendationRound: recommendationRound ?? this.recommendationRound,
      placeCount: placeCount ?? this.placeCount,
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

  CourseDraft removePlace(String placeId) => copyWith(places: places.where((p) => p.id != placeId).toList());

  CourseDraft reject(String placeId) => copyWith(rejectedPlaceIds: {...rejectedPlaceIds, placeId});

  static CourseDraft fromCourse(Course course) => CourseDraft(
    name: course.title,
    date: course.date,
    startTime: course.startTime,
    moodKeys: course.moodKeys,
    places: course.stops.where((s) => !s.isAi).map((s) => s.place).toList(),
    companion: course.isParty ? Companion.party : Companion.solo,
    partyId: course.partyId,
  );
}
