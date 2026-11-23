import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../place/domain/place.dart';
import 'course_schedule.dart';

/// 코스 안 장소의 출처. UI에서 항상 구분한다 (AI = 주황 ✦ + 이유 라벨).
enum PlaceSource { user, ai }

enum Companion { solo, party }

/// 이동 수단 (표시용). 서버 값과의 매핑은 NEEDS BACKEND.
enum TransportMode {
  walk('도보', LucideIcons.footprints),
  bus('버스', LucideIcons.bus),
  subway('지하철', LucideIcons.trainFront),
  car('차량', LucideIcons.car),
  unknown('이동', LucideIcons.route);

  const TransportMode(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// 다음 장소까지 이동. 서버가 실제 길로 잰 이동 시간을 주면 [RouteLeg.new](20번, 서버 요청 대기),
/// 그 전에는 앱이 좌표로 계산한 직선거리 [RouteLeg.straight]를 `약 500m`로 보여 준다 (21번 A안)
class RouteLeg {
  const RouteLeg({required TransportMode this.mode, required int this.minutes}) : meters = null;
  const RouteLeg.straight(double this.meters) : mode = null, minutes = null;

  final TransportMode? mode;
  final int? minutes;

  /// 직선거리(m)
  final double? meters;

  IconData get icon => mode?.icon ?? LucideIcons.moveHorizontal;

  String get label => meters == null ? '${mode!.label} $minutes분' : '약 ${_roughDistance(meters!)}';

  /// 100m 미만은 10m, 1km 미만은 100m, 그 위는 0.1km 단위로 반올림
  static String _roughDistance(double meters) {
    final step = meters < 100 ? 10 : 100;
    final rounded = ((meters / step).round() * step).clamp(10, double.infinity).toInt();
    return rounded < 1000 ? '${rounded}m' : '${(meters / 1000).toStringAsFixed(1)}km';
  }
}

/// AI가 추천할 때 찾아본 글 (서버 장소별 `web_evidence`, 2번). 장소 시트 '추천에 쓴 글 n개'에서 보여 준다
class PlaceEvidence {
  const PlaceEvidence({required this.url, this.quote, this.publishedAt});
  final String url;

  /// 글에서 따온 한 줄
  final String? quote;
  final DateTime? publishedAt;

  /// 'blog.naver.com' (주소 앞 www.는 뺀다)
  String get host {
    final host = Uri.tryParse(url)?.host ?? '';
    return (host.isEmpty ? url : host).replaceFirst(RegExp(r'^www\.'), '');
  }
}

/// 코스의 한 장소
class CourseStop {
  const CourseStop({
    required this.place,
    required this.source,
    this.aiReason,
    this.arrivalTime,
    this.nextLeg,
    this.evidence = const [],
  });

  final Place place;
  final PlaceSource source;

  /// AI 추천 이유 (예: 산책 취향 보완). 점수는 노출하지 않는다.
  final String? aiReason;
  final TimeOfDay? arrivalTime;
  final RouteLeg? nextLeg;

  /// 추천에 쓴 글 (AI 장소만, 서버가 주면)
  final List<PlaceEvidence> evidence;

  bool get isAi => source == PlaceSource.ai;
}

/// 여행 분위기 옵션 (서버 키워드 체계)
class MoodOption {
  const MoodOption({required this.key, required this.label});
  final String key;
  final String label;
}

/// AI 추천 결과
class Recommendation {
  const Recommendation({required this.stops, this.description, this.taste, this.schedule});

  final List<CourseStop> stops;
  final String? description;

  /// 이 추천에 반영한 취향 (없으면 일정 카드에 한 줄을 띄우지 않는다)
  final AppliedTaste? taste;

  /// 서버 예상 일정 (21번). 없으면 null
  final EstimatedSchedule? schedule;
}

/// 추천할 때 반영한 취향 (서버 `taste_profile`, 07 D46). 일정 카드에 "○○ · ○○ 취향을 반영했어요" 한 줄로 보여 준다.
class AppliedTaste {
  const AppliedTaste({required this.words, this.memberCount = 1, this.matches = const {}, this.gaps = const []});

  /// 파티 코스: 장소 id → 그 장소가 강하게 맞는 파티원 id (서버 `group_blend.per_user[].strong_match_places`).
  /// 추천했을 때 값이라 편집으로 빠진 장소가 남을 수 있어 화면은 지금 일정에 있는 장소만 보여 준다 (07 D46)
  final Map<String, List<String>> matches;

  /// 파티 코스: 반영되지 못한 파티원 (서버 `represented: false` / `insufficient_history`)
  final List<TasteGap> gaps;

  /// 펼쳐서 볼 내용이 있는지
  bool get hasDetail => memberCount > 1 && (matches.isNotEmpty || gaps.isNotEmpty);

  /// 보여 줄 취향 단어 (서버 순서, 넓은 지도 분류 이름은 뺀 것).
  /// 파티 코스는 2명 이상이 공유한 단어만이고, 비어 있으면 "파티원 n명의 취향을 반영했어요"
  final List<String> words;

  /// 취향을 모은 사람 수. 2 이상이면 파티 코스 ("파티원 n명의 …")
  final int memberCount;
}

/// 반영되지 못한 파티원과 그 이유
class TasteGap {
  const TasteGap({required this.memberId, required this.noHistory});
  final String memberId;

  /// true: 저장한 장소가 없어 반영 못 함 / false: 잘 맞는 장소를 찾지 못함
  final bool noHistory;
}

/// AI 추천 진행 단계 (화면에 보여 주는 묶음). 서버의 세부 단계는 데이터 계층에서 이 값으로 묶는다.
/// [matchTaste]는 파티 코스에서만 거친다.
enum RecommendationStage { findCandidates, checkPlaces, matchTaste, organize }

/// 추천하지 않는 장소 (사용자가 "앞으로 추천하지 않기"로 차단한 AI 추천 장소).
/// 모든 코스 추천에서 제외된다. 이번 코스에서만 뺀 장소는 [CourseDraft.rejectedPlaceIds]에 둔다.
class BlockedPlace {
  const BlockedPlace({required this.place, this.blockedAt});
  final Place place;

  /// 차단한 날. 팀 서버는 주지 않는다 (NEEDS BACKEND) — 없으면 화면에서 날짜를 빼고 보여 준다.
  final DateTime? blockedAt;
}

/// 저장하지 않은 추천 결과 (13번, 홈 맨 위 안내)
class UnsavedRecommendation {
  const UnsavedRecommendation({required this.course, required this.receivedAt, this.regionLabel});

  final Course course;

  /// 이 기기에서 추천을 받은 시각 (서버는 코스를 만든 시각을 주지 않는다)
  final DateTime receivedAt;

  /// 첫 장소 주소의 구 · 시 ('성동구'). 서버 초안에는 코스 이름이 없어 이름 대신 쓴다
  final String? regionLabel;

  /// 초안에는 이름이 없다 — 지역 이름으로 대신한다 ('성동구 코스')
  String get title => regionLabel == null ? '추천 코스' : '$regionLabel 코스';
}

/// 오늘 추천 사용량 (서버 `GET /me/usage`, 12번). 서버 한도는 추천 횟수가 아니라 AI 호출 수 · 비용이라
/// 남은 추천 횟수는 알 수 없다 — 다 썼는지와 초기화 시각만 쓴다.
class RecommendationQuota {
  const RecommendationQuota({required this.exhausted, required this.resetAt});

  /// 오늘 호출 수나 비용 한도를 다 썼는지
  final bool exhausted;

  /// 다시 쓸 수 있는 시각 (서버는 UTC 0시 = 한국 오전 9시에 초기화)
  final DateTime resetAt;
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
    this.memberNames = const [],
    this.tags = const [],
    this.stopCategoryKeys = const [],
    this.stopNames = const [],
    this.stopIsAi = const [],
    this.startTime,
    this.distanceKm,
  });

  final String id;
  final String title;
  final String? regionLabel;
  final int placeCount;
  final DateTime? date;
  final String? thumbnailUrl;
  final bool isParty;
  final int memberCount;

  /// 파티원 이름 (나 포함, 서버 순서). NEEDS BACKEND: 목록 summary에 이름이 오는지
  final List<String> memberNames;
  final List<String> tags;

  /// 일정 장소의 카테고리 키(순서대로). 사진이 없을 때 앞 칸에 카테고리 아이콘을 모아 보여 준다.
  final List<String> stopCategoryKeys;

  /// 일정 장소 이름(순서대로, [stopCategoryKeys]와 같은 길이). 홈 코스 카드의 장소 줄. 없으면 빈 목록
  final List<String> stopNames;

  /// 일정 장소가 AI 추천인지(순서대로). 홈 장소 줄에서 ✦로 구분한다
  final List<bool> stopIsAi;

  /// 출발 시간 (팀 서버 `start_time`). 없으면 null
  final TimeOfDay? startTime;

  /// 장소 사이 직선 거리 합 (팀 서버 `distance_km`). 없으면 null
  final double? distanceKm;

  CourseSummary copyWith({required int memberCount}) => CourseSummary(
    id: id,
    title: title,
    regionLabel: regionLabel,
    placeCount: placeCount,
    date: date,
    thumbnailUrl: thumbnailUrl,
    isParty: isParty,
    memberCount: memberCount,
    memberNames: memberNames,
    tags: tags,
    stopCategoryKeys: stopCategoryKeys,
    stopNames: stopNames,
    stopIsAi: stopIsAi,
    startTime: startTime,
    distanceKm: distanceKm,
  );
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
    required this.stops,
    this.moodKeys = const {},
    this.partyId,
    this.canEdit = true,
    this.taste,
    this.schedule,
    this.ownerId,
  });

  final String id;
  final String title;
  final DateTime? date;
  final TimeOfDay? startTime;
  final bool isParty;
  final int memberCount;
  final List<CourseStop> stops;
  final Set<String> moodKeys;
  final String? partyId;

  /// 편집 가능 여부 (서버 값). 파티 코스는 초대된 참여자도 편집할 수 있다 (07 D23)
  final bool canEdit;

  /// 이 코스를 추천할 때 반영한 취향 (07 D46)
  final AppliedTaste? taste;

  /// 서버 예상 일정 (21번). 없으면 null — 화면은 [withEstimatedTimes]로 시각 · 이동 줄을 붙인다
  final EstimatedSchedule? schedule;

  /// 코스를 만든 사람 id (서버 `owner`, 19번). 파티 코스 상세에서 파티원 이름으로 바꿔 보여 준다
  final String? ownerId;

  Course copyWith({required int memberCount}) => Course(
    id: id,
    title: title,
    date: date,
    startTime: startTime,
    isParty: isParty,
    memberCount: memberCount,
    stops: stops,
    moodKeys: moodKeys,
    partyId: partyId,
    canEdit: canEdit,
    taste: taste,
    schedule: schedule,
    ownerId: ownerId,
  );
}
