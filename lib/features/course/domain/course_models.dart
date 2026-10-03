import 'package:flutter/material.dart';

import '../../place/domain/place.dart';

/// 코스 안 장소의 출처. UI에서 항상 구분한다 (AI = 주황 ✦ + 이유 라벨).
enum PlaceSource { user, ai }

enum Companion { solo, party }

/// 이동 수단 (표시용). 서버 값과의 매핑은 NEEDS BACKEND.
enum TransportMode {
  walk('도보', Icons.directions_walk_rounded),
  bus('버스', Icons.directions_bus_rounded),
  subway('지하철', Icons.subway_rounded),
  car('차량', Icons.directions_car_rounded),
  unknown('이동', Icons.route_rounded);

  const TransportMode(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// 다음 장소까지 이동 (서버 제공)
class RouteLeg {
  const RouteLeg({required this.mode, required this.minutes});
  final TransportMode mode;
  final int minutes;

  String get label => '${mode.label} $minutes분';
}

/// 코스의 한 장소
class CourseStop {
  const CourseStop({required this.place, required this.source, this.aiReason, this.arrivalTime, this.nextLeg});

  final Place place;
  final PlaceSource source;

  /// AI 추천 이유 (예: 산책 취향 보완). 점수는 노출하지 않는다.
  final String? aiReason;
  final TimeOfDay? arrivalTime;
  final RouteLeg? nextLeg;

  bool get isAi => source == PlaceSource.ai;
}

/// 여행 분위기 옵션 (서버 키워드 체계)
class MoodOption {
  const MoodOption({required this.key, required this.label});
  final String key;
  final String label;
}

/// 취향 반영 비율 (예: 카페 42%). 값은 서버가 준다.
class PreferenceShare {
  const PreferenceShare({required this.label, required this.percent});
  final String label;
  final int percent;
}

/// AI 추천 결과
class Recommendation {
  const Recommendation({
    this.recommendationId,
    required this.stops,
    this.headline,
    this.description,
    this.preferenceMix = const [],
  });

  /// 서버가 추천 세션을 보존하는 경우의 ID (NEEDS BACKEND: 무상태 여부 확인)
  final String? recommendationId;
  final List<CourseStop> stops;
  final String? headline;
  final String? description;
  final List<PreferenceShare> preferenceMix;
}

/// 코스 목록 카드
class CourseSummary {
  const CourseSummary({
    required this.id,
    required this.title,
    this.regionLabel,
    required this.placeCount,
    this.date,
    this.thumbnailUrl,
    this.isParty = false,
    this.memberCount = 1,
    this.statusLabel,
    this.tags = const [],
    this.bookmarked = false,
  });

  final String id;
  final String title;
  final String? regionLabel;
  final int placeCount;
  final DateTime? date;
  final String? thumbnailUrl;
  final bool isParty;
  final int memberCount;

  /// 예: "함께 계획 중" (서버 상태 문구)
  final String? statusLabel;
  final List<String> tags;
  final bool bookmarked;
}

/// "이런 코스는 어때요?" (서버 추천 코스)
class SuggestedCourse {
  const SuggestedCourse({required this.id, required this.title, required this.placeCount, this.durationLabel, this.imageUrl});
  final String id;
  final String title;
  final int placeCount;
  final String? durationLabel;
  final String? imageUrl;
}

/// 코스 상세
class Course {
  const Course({
    required this.id,
    required this.title,
    this.date,
    this.startTime,
    this.isParty = false,
    this.memberCount = 1,
    this.totalDuration,
    this.isShared = false,
    required this.stops,
    this.moodKeys = const {},
    this.partyId,
    this.canEdit = true,
  });

  final String id;
  final String title;
  final DateTime? date;
  final TimeOfDay? startTime;
  final bool isParty;
  final int memberCount;
  final Duration? totalDuration;
  final bool isShared;
  final List<CourseStop> stops;
  final Set<String> moodKeys;
  final String? partyId;

  /// 소유자/참여자 권한 차이 (정책 확정 필요)
  final bool canEdit;
}
