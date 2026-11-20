import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart' show DateUtils, TimeOfDay;

import '../../../core/utils/formatters.dart';
import '../../../core/config/env.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/models/geo_point.dart';
import '../../../core/network/api_client.dart';
import '../../auth/data/auth_repositories.dart' show IdSignupRules;
import '../../auth/domain/auth_models.dart';
import '../../auth/domain/auth_repository.dart';
import '../../saved/data/api_saved_repository.dart';
import '../../saved/domain/saved_models.dart';
import '../../saved/domain/saved_repository.dart';
import '../../place/domain/place.dart';
import '../../place/domain/place_repository.dart';
import '../../place/domain/place_search_repository.dart';
import '../../course/domain/course_models.dart';
import '../../course/domain/course_draft.dart';
import '../../course/domain/course_repository.dart';
import '../../extraction/domain/extraction_models.dart';
import '../../extraction/domain/extraction_repository.dart';
import '../../home/domain/home_models.dart';
import '../../home/domain/home_repository.dart';
import '../../party/domain/party_models.dart';
import '../../party/domain/party_repository.dart';
import '../../my/domain/my_models.dart';
import '../../preference/domain/preference_models.dart';
import '../../preference/domain/preference_repository.dart';
import 'platform_client.dart';

/// 추천 요청의 `area`: 고른 장소 주소의 앞 두 단어(시도 + 시군구) 중 가장 많은 것. 같으면 먼저 고른 쪽,
/// 주소가 빈 곳(추천받은 곳 일부)은 세지 않는다. 서버는 이 지역 안에서 AI 추천 장소를 찾고, 다시 추천해도 처음 값을 쓴다.
/// 고른 순서는 추천에 쓰이지 않으므로 지역도 순서가 아니라 고른 곳들이 모인 곳으로 정한다.
@visibleForTesting
String courseArea(List<Place> places, {String fallback = '서울 마포구'}) {
  final counts = <String, int>{};
  for (final p in places) {
    final area = p.address.trim().split(RegExp(r'\s+')).take(2).join(' ');
    if (area.isNotEmpty) counts[area] = (counts[area] ?? 0) + 1;
  }
  if (counts.isEmpty) return fallback;
  // Map은 넣은 순서를 지키므로, 같은 수면 먼저 고른 지역이 남는다
  return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
}

/// 코스 안 장소의 키. 서버는 `key`(정규 키)를 주고, 없으면 `id`를 쓴다.
String _placeKey(dynamic stop) => (stop['key'] ?? stop['id']).toString();

/// TimeOfDay → 서버 `start_time` 형식 `HH:mm`
String? _hhmm(TimeOfDay? t) =>
    t == null ? null : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

class PlatformAuthRepository implements AuthRepository {
  PlatformAuthRepository(this._platform);
  final PlatformClient _platform;
  AuthUser _user(dynamic json) => AuthUser(
    id: json['id'] as String,
    nickname: json['name'] as String,
    handle: json['login'] as String?,
  );

  @override
  Future<AuthUser?> restoreSession() async {
    try {
      return _user((await _platform.me())['user']);
    } on UnauthorizedFailure {
      return null;
    }
  }

  @override
  Future<SignInResult> signInWithId({
    required String login,
    required String password,
  }) async {
    try {
      final userJson = await _platform.post('/auth/login', {
        'login': login.trim(),
        'password': password,
      });
      _startSession(userJson);
      return SignedIn(_user(userJson));
    } on UnauthorizedFailure {
      return const InvalidCredentials();
    }
  }

  /// 서버 오류(409 중복, 422 형식)를 칸별 오류와 화면 말투로 바꾼다.
  @override
  Future<AuthUser> signUpWithId({
    required String login,
    required String password,
    required String nickname,
  }) async {
    final errors = IdSignupRules.validate(login: login, password: password, nickname: nickname);
    if (errors.isNotEmpty) throw ValidationFailure(errors.values.first, fieldErrors: errors);
    try {
      final res = await _platform.client.dio.post<dynamic>('/auth/register', data: {
        'login': login.trim().toLowerCase(),
        'password': password,
        'name': nickname.trim(),
      });
      final userJson = res.data;
      _startSession(userJson);
      return _user(userJson);
    } on DioException catch (e) {
      throw switch (e.response?.statusCode) {
        409 => const ValidationFailure(IdSignupRules.loginTaken, fieldErrors: {'login': IdSignupRules.loginTaken}),
        422 => const ValidationFailure(IdSignupRules.loginInvalid, fieldErrors: {'login': IdSignupRules.loginInvalid}),
        _ => mapDioException(e),
      };
    }
  }

  /// 새 로그인 — 이전 사용자 캐시를 비운다.
  void _startSession(dynamic userJson) {
    _platform.places.clear();
    _platform.courses.clear();
    _platform.partySizes.clear();
    _platform.partyOwners.clear();
    _platform.lastCourseId = null;
    _platform.currentUserId = userJson['id'] as String;
  }

  @override
  Future<SignInResult> signInWithEmail({
    required String email,
    required String password,
  }) async => throw const NotImplementedFailure('이메일 로그인');

  @override
  Future<void> signOut() async {
    try {
      await _platform.post('/auth/logout');
    } finally {
      // 요청이 실패해도 앱에 남은 이 계정의 데이터는 지운다.
      _platform.places.clear();
      _platform.courses.clear();
      _platform.lastCourseId = null;
      _platform.currentUserId = null;
    }
  }

  @override
  Future<SignInResult> signInWithSocial(SocialProvider provider) async =>
      throw const NotImplementedFailure('소셜 로그인');
  @override
  Future<AuthUser> linkExistingAccount(AccountConflict conflict) async =>
      throw const NotImplementedFailure('계정 연결');
  @override
  Future<List<TermsItem>> fetchTerms() async =>
      throw const NotImplementedFailure('약관');
  @override
  Future<void> agreeTerms(Set<String> ids) async =>
      throw const NotImplementedFailure('약관');
  @override
  Future<AuthUser> completeProfile({required String nickname}) async => throw const NotImplementedFailure('프로필 수정');
}

class PlatformSavedRepository extends ApiSavedRepository {
  PlatformSavedRepository(this._platform) : super(_platform.client);
  final PlatformClient _platform;
  /// 저장 개수 · 카테고리. 서버 `/mobile/summary`는 코스로 들어온 AI 추천 장소까지 세서,
  /// 카테고리 탭에 보이는 직접 저장한 곳만 앱이 센다 (07 D44).
  /// NEEDS BACKEND: 서버 요약이 `action_type`별로 나뉘면 서버 값을 쓴다.
  @override
  Future<SavedSummary> fetchSummary() async {
    final counts = <String, int>{};
    for (final place in (await _split()).mine) {
      final key = categoryKeyOf(place);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return SavedSummary(
      totalCount: counts.values.fold(0, (sum, n) => sum + n),
      categories: [
        for (final entry in counts.entries)
          PlaceCategory(key: entry.key, label: categoryShortLabel(entry.key), count: entry.value),
      ],
    );
  }

  /// 서버 요약과 같은 카테고리 키: 카카오 업종 전체 경로, 없으면 대분류 이름, 그것도 없으면 '기타'
  static String categoryKeyOf(Json place) {
    for (final field in ['category', 'category_group_name']) {
      final value = place[field];
      if (value is String && value.isNotEmpty) return value;
    }
    return '기타';
  }

  @override
  Future<List<SavedPlaceItem>> fetchSavedPlaces(SavedPlaceQuery query) async {
    if (query.collectionId != null) throw const NotImplementedFailure('보관함');
    bool matches(Json place) => query.keyword == null || place['name'].toString().contains(query.keyword!);
    return [
      for (final place in (await _split()).mine)
        if (matches(place)) SavedPlaceItem(place: _platform.place(place, saved: true)),
    ];
  }

  @override
  Future<List<SavedPlaceItem>> fetchAiSavedPlaces() async => [
    for (final (place, course) in (await _split()).ai)
      SavedPlaceItem(place: _platform.place(place, saved: true), recommendedIn: course),
  ];

  /// 코스를 저장하면 서버가 일정의 모든 장소를 저장 목록에 `action_type: course_confirmed`로 넣는다
  /// (취향 가중치 0.8, 팀이 일부러 정한 동작). 그중 확정 코스 일정에서 AI가 추천한 곳(`saved`가 아님)은
  /// AI 추천 탭으로, 직접 고른 장소로 코스에 넣은 곳은 카테고리로 나눈다. 어느 코스인지 못 찾으면
  /// (코스 목록은 최근 30개만 옴) AI 추천으로 본다 (07 D44).
  Future<({List<Json> mine, List<(Json, String?)> ai})> _split() async {
    final me = await _platform.me();
    final places = [for (final p in me['places'] as List) Map<String, dynamic>.from(p as Map)];
    final fromCourses = [for (final p in places) if (p['action_type'] == 'course_confirmed') p['key'].toString()];
    if (fromCourses.isEmpty) return (mine: places, ai: <(Json, String?)>[]);
    final stops = await _courseStops(me, fromCourses);
    final mine = <Json>[];
    final ai = <(Json, String?)>[];
    for (final place in places) {
      final key = place['key'].toString();
      final pickedOnly = stops.picked.contains(key) && !stops.aiCourse.containsKey(key);
      if (place['action_type'] != 'course_confirmed' || pickedOnly) {
        mine.add(place);
      } else {
        ai.add((place, stops.aiCourse[key]));
      }
    }
    return (mine: mine, ai: ai);
  }

  /// 확정한 코스(개인 + 내가 속한 파티) 일정에서 장소 key별로 AI가 추천한 코스 이름과 직접 고른 장소를 모은다.
  /// 같은 장소 목록이면 다시 받지 않는다. 최근에 고친 코스가 앞에 온다.
  Future<({Map<String, String> aiCourse, Set<String> picked})> _courseStops(Json me, List<String> keys) async {
    final signature = (keys.toList()..sort()).join(',');
    if (_stopsFor == signature && _stops != null) return _stops!;
    final rows = [
      ...await _platform.get('/courses') as List,
      for (final party in me['parties'] as List) ...await _platform.get('/courses', {'party_id': party['id']}) as List,
    ];
    final aiCourse = <String, String>{};
    final picked = <String>{};
    for (final row in rows) {
      final course = Map<String, dynamic>.from(row as Map);
      if (course['status'] != 'confirmed') continue;
      for (final stop in course['itinerary'] as List) {
        final key = (stop['key'] ?? stop['id']).toString();
        if (stop['saved'] == true) {
          picked.add(key);
        } else {
          aiCourse.putIfAbsent(key, () => (course['title'] ?? '추천 코스').toString());
        }
      }
    }
    _stopsFor = signature;
    return _stops = (aiCourse: aiCourse, picked: picked);
  }

  String? _stopsFor;
  ({Map<String, String> aiCourse, Set<String> picked})? _stops;

  @override
  Future<List<SavedPlaceItem>> fetchSavedPlacesNearby(
    GeoPoint center,
    int radiusMeters,
    SavedPlaceQuery query,
  ) async => (await fetchSavedPlaces(query))
      .where((item) => item.place.location != null && center.distanceTo(item.place.location!) <= radiusMeters)
      .toList();
  @override
  Future<List<PlaceCollection>> fetchCollections() async => [];
  @override
  Future<List<String>> fetchPlaceCollectionIds(String placeId) async => [];
  @override
  Future<void> unsavePlace(String placeId) => _platform.unsave(placeId);
  @override
  Future<void> savePlaces({
    required List<String> placeIds,
    required List<String> collectionIds,
  }) async {
    if (collectionIds.isNotEmpty) throw const NotImplementedFailure('보관함');
    for (final id in placeIds) {
      await _platform.save(id);
    }
  }
}

class PlatformPlaceRepository implements PlaceRepository {
  PlatformPlaceRepository(this._platform);
  final PlatformClient _platform;
  @override
  Future<PlaceDetail> fetchPlace(String placeId) async {
    await _platform.me();
    final place = _platform.places[placeId];
    if (place == null) throw const NotFoundFailure();
    return PlaceDetail(place: _platform.place(place));
  }
}

/// 지도에서 검색하기: GET /places/search. 저장 상태를 맞추려고 먼저 /me를 읽는다.
class PlatformPlaceSearchRepository implements PlaceSearchRepository {
  PlatformPlaceSearchRepository(this._platform);
  final PlatformClient _platform;
  @override
  Future<List<Place>> search(String query, {GeoPoint? near}) async {
    await _platform.me();
    return _platform.search(query, near: near);
  }
}

class PlatformCourseRepository implements CourseRepository {
  PlatformCourseRepository(this._platform);
  final PlatformClient _platform;
  CourseSummary _summary(Json course) => CourseSummary(
    id: course['id'] as String,
    title: (course['title'] ?? '추천 코스').toString(),
    placeCount: (course['itinerary'] as List).length,
    isParty: course['party_id'] != null,
    date: DateTime.tryParse((course['date'] ?? '').toString()),
    memberCount: course['party_id'] == null ? 1 : _platform.partySizes[course['party_id']] ?? 1,
    regionLabel: _region(course['itinerary'] as List),
    stopCategoryKeys: [
      for (final stop in course['itinerary'] as List) PlatformSavedRepository.categoryKeyOf(Map<String, dynamic>.from(stop as Map)),
    ],
    stopNames: [for (final stop in course['itinerary'] as List) ((stop as Map)['name'] ?? '').toString()],
    // 내가 고른 곳은 saved: true (나머지는 AI 추천)
    stopIsAi: [for (final stop in course['itinerary'] as List) (stop as Map)['saved'] != true],
    startTime: _time(course['start_time']),
    distanceKm: (course['distance_km'] as num?)?.toDouble(),
  );

  /// '11:00' 또는 '11:00:00' → TimeOfDay
  static TimeOfDay? _time(Object? value) {
    final parts = (value ?? '').toString().split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    return h == null || m == null ? null : TimeOfDay(hour: h, minute: m);
  }

  /// 지역 줄: 첫 장소 주소의 구 · 시 ('서울 강서구 화곡로 416' → '강서구'). 주소가 없으면 비운다.
  static String? _region(List itinerary) {
    for (final stop in itinerary) {
      final parts = ((stop as Map)['address'] ?? '').toString().trim().split(RegExp(r'\s+'));
      if (parts.length >= 2 && parts[1].isNotEmpty) return parts[1];
    }
    return null;
  }

  Future<List<Json>> _courseRows([String? partyId]) async {
    final rows = await _platform.get('/courses', partyId == null ? null : {'party_id': partyId}) as List;
    return [for (final row in rows) Map<String, dynamic>.from(row as Map)];
  }

  /// 서버는 추천을 받을 때마다 결과를 초안(draft)으로 저장한다. 사용자가 저장한 코스는 확정(confirmed)이라
  /// 목록 · 홈에는 확정한 코스만 쓴다 (저장하지 않은 추천 결과는 보이지 않게).
  static bool isSaved(Json course) => course['status'] == 'confirmed';

  /// 홈 맨 위 카드용: 저장한 코스 중 오늘 이후(오늘 포함) 날짜, 날짜가 없으면 포함 (Mock과 같은 기준, 07 D20)
  static bool isUpcoming(Json course, DateTime today) {
    if (!isSaved(course)) return false;
    final date = DateTime.tryParse((course['date'] ?? '').toString());
    return date == null || !DateUtils.dateOnly(date).isBefore(today);
  }

  Future<List<Json>> _partyCourseRows() async {
    final me = await _platform.me();
    return [
      for (final party in me['parties'] as List) ...await _courseRows(party['id'] as String),
    ];
  }

  @override
  Future<List<CourseSummary>> fetchMyCourses() async => [
    for (final course in await _courseRows()) if (isSaved(course)) _summary(course),
  ];

  @override
  Future<List<CourseSummary>> fetchPartyCourses() async => [
    for (final course in await _partyCourseRows()) if (isSaved(course)) _summary(course),
  ];

  /// 개인 코스(GET /courses)에는 파티 코스가 없어 파티별로 따로 받아 합친다.
  @override
  Future<List<CourseSummary>> fetchActiveCourses() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final courses = [...await _courseRows(), ...await _partyCourseRows()];
    return [
      for (final course in courses) if (isUpcoming(course, today)) _summary(course),
    ];
  }
  @override
  Future<List<SuggestedCourse>> fetchSuggestedCourses() async => [];
  @override
  Future<List<MoodOption>> fetchMoodOptions() async => [];
  @override
  Future<Course> fetchCourse(String id) async =>
      _platform.course(Map<String, dynamic>.from(await _platform.get('/courses/$id') as Map));
  @override
  Future<Recommendation> recommend({
    required CourseDraft draft,
    List<CourseStop> currentStops = const [],
    void Function(RecommendationStage stage)? onStage,
  }) async {
    _platform.cancelRequested = false;
    void onServerStage(String serverStage) {
      final mapped = recommendationStage(serverStage);
      if (mapped != null) onStage?.call(mapped);
    }

    onStage?.call(RecommendationStage.findCandidates);
    final jobs = [for (final job in await _platform.get('/jobs') as List) Map<String, dynamic>.from(job as Map)];
    // 방금 취소한 job은 서버가 멈출 때까지 기다린 뒤 새로 시작한다 (그 전에는 서버가 409)
    for (final job in jobs.where((job) => job['status'] == 'cancelling')) {
      await _platform.waitUntilSettled(job['id'] as String);
    }
    final running = jobs.where((job) => job['status'] != 'cancelling');
    if (running.isNotEmpty) {
      return _recommendation(await _platform.poll(running.first['id'] as String, onStage: onServerStage));
    }
    final previous = _platform.lastCourseId;
    final exclusionTokens = <String>[];
    for (final id in draft.rejectedPlaceIds) {
      exclusionTokens.add(await _platform.token(id));
    }
    // 지난 추천에서 내가 고른 장소(saved)들. 이번 초안과 같으면 새로 만들지 않고 지난 코스를 바꾼다.
    final previousAnchors = previous == null
        ? <String>{}
        : {
            for (final stop in _platform.courses[previous]?['itinerary'] as List? ?? [])
              if (stop['saved'] == true) _placeKey(stop),
          };
    final sameAnchors =
        previousAnchors.length == draft.placeIds.length &&
        previousAnchors.containsAll(draft.placeIds);
    dynamic started;
    if (previous != null &&
        sameAnchors &&
        draft.recommendationRound > 0 &&
        _platform.courses[previous]?['status'] != 'confirmed') {
      var old = _platform.courses[previous]!;
      final removed = [
        for (final stop in old['itinerary'] as List)
          if (draft.rejectedPlaceIds.contains(_placeKey(stop))) stop,
      ];
      if (removed.length == 1 &&
          currentStops.length == (old['itinerary'] as List).length - 1) {
        if (_platform.cancelRequested) throw const CancelledFailure();
        started = await _platform.post('/courses/$previous/replace', {
          'revision': old['revision'],
          'place_key': removed.first['key'],
        });
        return _recommendation(await _platform.poll(started['job_id'] as String, onStage: onServerStage));
      }
      // 다시 추천하기 전에 앱에서 뺀 장소를 서버 코스에서도 빼 둔다 — 그래야 서버가 제외 목록을 유지한다.
      for (final stop in List<dynamic>.from(old['itinerary'] as List)) {
        final id = _placeKey(stop);
        if (draft.rejectedPlaceIds.contains(id)) {
          old = Map<String, dynamic>.from(
            await _platform.delete('/courses/$previous/places', {'revision': old['revision'], 'place_key': id}) as Map,
          );
        }
      }
      _platform.courses[previous] = old;
      if (_platform.cancelRequested) throw const CancelledFailure();
      started = await _platform.post('/courses/$previous/replace', {
        'revision': old['revision'],
      });
    } else {
      if (draft.places.isEmpty || draft.places.length > 6) {
        throw const ValidationFailure('필수 장소를 1~6곳 선택해주세요.');
      }
      final tokens = <String>[];
      for (final p in draft.places) {
        tokens.add(await _platform.token(p.id));
      }
      if (_platform.cancelRequested) throw const CancelledFailure();
      started = await _platform.post('/jobs', {
        'area': courseArea(draft.places),
        'place_tokens': tokens,
        'excluded_place_tokens': exclusionTokens,
        'place_count': (draft.places.length + 3).clamp(1, 6),
        'party_id': draft.companion == Companion.party ? draft.partyId : null,
        // 서버가 출발 시간으로 식사 · 술집 수와 방문 순서를 정한다(없으면 12:00 기준)
        'visit_date': draft.date?.toIso8601String().substring(0, 10),
        'start_time': _hhmm(draft.startTime),
      });
    }
    return _recommendation(await _platform.poll(started['job_id'] as String, onStage: onServerStage));
  }

  @override
  Future<void> cancelRecommendation() => _platform.cancelRecommendation();

  @override
  Future<String> courseLink(String courseId) async => webAppLink('/courses/$courseId');

  /// 서버 job stage → 화면 단계. 화면은 앞으로만 진행하므로 순서가 오가도 괜찮다.
  /// 모르는 값(queued 등)은 null — 지금 단계를 유지한다.
  static RecommendationStage? recommendationStage(String stage) => switch (stage) {
    'starting' || 'preparing' || 'searching' || 'searching_member_preferences' || 'refilling' =>
      RecommendationStage.findCandidates,
    'extracting_attributes' || 'verifying' => RecommendationStage.checkPlaces,
    'balancing_group' => RecommendationStage.matchTaste,
    'reviewing' || 'saving' => RecommendationStage.organize,
    _ => null,
  };

  Recommendation _recommendation(Json course) => Recommendation(
    stops: _platform.stops(course),
    taste: PlatformClient.appliedTaste(course['taste_profile'], itinerary: course['itinerary'] as List?),
    description: [
      course['recommendation_reason'],
      ...(course['warnings'] as List? ?? []),
    ].whereType<String>().join('\n'),
  );

  @override
  Future<Course> createCourse({
    required CourseDraft draft,
    required List<CourseStop> stops,
  }) async {
    final id = _platform.lastCourseId;
    if (id == null) throw const ValidationFailure('추천을 먼저 받아주세요.');
    final old = _platform.courses[id]!;
    final changed = Map<String, dynamic>.from(
      await _platform.post('/mobile/courses/$id', {
            'revision': old['revision'],
            'title': draft.name,
            'date': draft.date?.toIso8601String(),
            'start_time': _hhmm(draft.startTime),
            'ordered_keys': stops.map((s) => s.place.id).toList(),
          })
          as Map,
    );
    final confirmed = await _platform.post('/courses/$id/confirm', {
      'revision': changed['revision'],
    });
    return _platform.course(Map<String, dynamic>.from(confirmed as Map));
  }

  /// 차단 목록. 서버는 차단한 날을 주지 않는다 (NEEDS BACKEND).
  @override
  Future<List<BlockedPlace>> fetchBlockedPlaces() async => [
    for (final raw in await _platform.get('/me/blocks') as List)
      BlockedPlace(place: _platform.place(Map<String, dynamic>.from(raw as Map))),
  ];

  /// 서버에는 따로 차단하는 API가 없고, 코스에서 장소를 뺄 때 `block_future`로만 차단한다.
  /// 그 장소가 든 추천 코스를 찾아 서버에서도 빼면서 차단한다. 코스가 없으면 NEEDS BACKEND.
  @override
  Future<void> blockPlace(String placeId) async {
    for (final course in [?_platform.lastCourseId, ..._platform.courses.keys]) {
      final old = _platform.courses[course];
      if (old == null || old['status'] == 'confirmed') continue;
      final hasPlace = (old['itinerary'] as List).any((stop) => _placeKey(stop) == placeId);
      if (!hasPlace) continue;
      _platform.courses[course] = Map<String, dynamic>.from(
        await _platform.delete('/courses/$course/places', {
              'revision': old['revision'],
              'place_key': placeId,
              'block_future': true,
            })
            as Map,
      );
      return;
    }
    throw const NotImplementedFailure('코스 밖에서 장소 차단');
  }

  @override
  Future<void> unblockPlace(String placeId) async {
    await _platform.delete('/me/blocks/$placeId');
  }

  @override
  Future<Course> updateCourseStops({
    required String courseId,
    required List<CourseStop> stops,
  }) async {
    final old =
        _platform.courses[courseId] ??
        Map<String, dynamic>.from(await _platform.get('/courses/$courseId') as Map);
    return _platform.course(
      Map<String, dynamic>.from(
        await _platform.post('/mobile/courses/$courseId', {
              'revision': old['revision'],
              'ordered_keys': stops.map((s) => s.place.id).toList(),
            })
            as Map,
      ),
    );
  }
}

class PlatformHomeRepository implements HomeRepository {
  PlatformHomeRepository(this._platform);
  final PlatformClient _platform;
  @override
  Future<HomeStats> fetchStats() async {
    final summary = await _platform.get('/mobile/summary');
    return HomeStats(
      savedPlaceCount: summary['saved_count'] as int,
    );
  }

  @override
  Future<List<Place>> fetchTrendingPlaces() async => [];
}

class PlatformMyRepository implements MyRepository {
  PlatformMyRepository(this._platform, this._saved, this._courses);
  final PlatformClient _platform;
  final SavedRepository _saved;
  final CourseRepository _courses;

  /// 이름만 서버 요약을 쓴다. 숫자는 눌러서 가는 목록과 같은 기준으로 앱이 센다 (07 D44와 같은 방식).
  /// 서버 `/mobile/summary`의 숫자는 목록과 달라서 마이와 목록이 어긋난다:
  /// - `saved_count`: 코스 저장으로 들어온 AI 추천 장소까지 센다 (저장됨 탭은 직접 저장한 곳만)
  /// - `created_course_count`: 저장하지 않은 추천 결과(draft)와 내가 만든 파티 코스까지 센다 (코스 탭 '내 코스'는 확정한 개인 코스만)
  /// - `joined_course_count`: 남이 만든 파티 코스만 센다 (코스 탭 '함께하는 코스'는 내가 만든 파티 코스도 포함)
  /// NEEDS BACKEND: 요약이 목록과 같은 기준(확정 코스만, 개인/파티 구분)으로 나뉘면 서버 값을 쓴다.
  @override
  Future<MyProfile> fetchProfile() async {
    final summary = await _platform.get('/mobile/summary');
    final (saved, mine, party) = await (
      _saved.fetchSummary(),
      _courses.fetchMyCourses(),
      _courses.fetchPartyCourses(),
    ).wait;
    return MyProfile(
      nickname: summary['name'] as String,
      savedPlaceCount: saved.totalCount,
      createdCourseCount: mine.length,
      joinedCourseCount: party.length,
    );
  }
}

class PlatformPreferenceRepository implements PreferenceRepository {
  PlatformPreferenceRepository(this._platform);
  // ignore: unused_field
  final PlatformClient _platform;
  @override
  Future<List<PreferenceGroup>> fetchGroups() async => [];
  @override
  Future<MyPreferences> fetchMine() async =>
      const MyPreferences(selectedKeys: {});
  @override
  Future<void> save({
    required Set<String> selectedKeys,
    required bool autoAnalysisEnabled,
  }) async => throw const NotImplementedFailure('수동 취향 설정');
}

/// 밖으로 보내는 링크(초대 · 코스). 브라우저는 지금 주소, 앱은 서버가 띄워 주는 웹 앱 주소로 만든다.
/// NEEDS BACKEND: 정식 링크 도메인 · 앱 링크(설치된 앱으로 바로 열기)
String webAppLink(String route) {
  final base = kIsWeb ? Uri.base : Uri.parse(Env.apiBaseUrl).replace(path: '/mobile-app/');
  return base.replace(fragment: route).toString();
}

/// 서버 파티 이름. 만들 때 한 번 정해지고 바꿀 수 없어서, 바뀌지 않는 만든 사람 이름으로 짓는다 (07 D38).
/// NEEDS BACKEND: 파티 이름 수정 API가 생기면 사용자가 이름을 정하게 바꾼다.
String partyNameFor(String ownerName) {
  final name = ownerName.trim();
  if (name.isEmpty) return '새 파티';
  const suffix = '님의 파티';
  const max = 60 - suffix.length; // 서버 이름 길이 제한 60자
  return '${name.length > max ? name.substring(0, max) : name}$suffix';
}

class PlatformPartyRepository implements PartyRepository {
  PlatformPartyRepository(this._platform);
  final PlatformClient _platform;
  @override
  Future<Party> createParty() async {
    final me = await _platform.me();
    final owner = ((me['user'] as Map)['name'] ?? '').toString();
    final created = await _platform.post('/parties', {'name': partyNameFor(owner)});
    _platform.partyOwners[created['id'] as String] = _platform.currentUserId!; // 만든 사람이 파티장
    return fetchParty(created['id'] as String);
  }

  /// 파티 목록 API는 따로 없고 GET /me의 parties에 멤버까지 같이 온다
  @override
  Future<List<Party>> fetchMyParties() async {
    final me = await _platform.me();
    return [
      for (final party in me['parties'] as List) _party(party['id'] as String, party['members'] as List),
    ];
  }

  @override
  Future<Party> fetchParty(String id) async {
    // 파티장은 GET /me에만 와서, 아직 모르면 한 번 받아 온다
    if (!_platform.partyOwners.containsKey(id)) await _platform.me();
    final party = await _platform.get('/parties/$id');
    return _party(id, party['members'] as List);
  }

  Party _party(String id, List members) => Party(
    id: id,
    isOwner: _platform.partyOwners[id] == _platform.currentUserId,
    members: [
      for (final member in members)
        PartyMember(
          id: member['id'] as String,
          nickname: member['name'] as String,
          isMe: member['id'] == _platform.currentUserId,
        ),
    ],
  );

  @override
  Future<InviteLink> createInviteLink(String id) async {
    final invite = await _platform.post('/parties/$id/invites');
    return InviteLink(url: webAppLink('/invites/${invite['code']}'));
  }

  @override
  Future<Invitation> fetchInvitation(String token) async {
    final invite = await _platform.get('/mobile/invites/$token');
    return Invitation(
      token: token,
      inviterName: invite['inviter'] as String,
      courseTitle: invite['name'] as String,
      memberCount: invite['member_count'] as int,
    );
  }

  @override
  Future<void> acceptInvitation(
    String token, {
    required bool shareMyPreferences,
  }) async {
    if (!shareMyPreferences) {
      throw const ValidationFailure('현재 서버의 파티 추천은 참여자 저장 취향을 함께 사용해요.');
    }
    await _platform.post('/parties/join', {'code': token});
  }

  @override
  Future<void> declineInvitation(String token) async {}
}

/// 팀 서버에는 링크 추출 기능이 없다 (NEEDS BACKEND). Mock 결과로 대신하지 않는다.
class PlatformExtractionRepository implements ExtractionRepository {
  PlatformExtractionRepository(this._platform);
  final PlatformClient _platform;

  @override
  Future<ExtractionResult> extract(String url) async => throw const NotImplementedFailure('링크로 장소 찾기');

  /// 서버에는 추출 기록이 없어, 저장 장소(/me)를 저장한 시각(saved_at) 순으로 대신 쓴다 (홈 '최근 저장한 곳').
  @override
  Future<List<RecentExtraction>> fetchRecent({required int limit}) async => recentFrom(
        [for (final place in (await _platform.me())['places'] as List) Map<String, dynamic>.from(place as Map)],
        limit: limit,
      );

  List<RecentExtraction> recentFrom(List<Json> places, {required int limit}) {
    final dated = [
      for (final place in places)
        if (DateTime.tryParse((place['saved_at'] ?? '').toString()) case final savedAt?) (place, savedAt.toLocal()),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    return [
      for (final (place, savedAt) in dated.take(limit))
        RecentExtraction(
          place: _platform.place(place, saved: true),
          extractedAt: savedAt,
        ),
    ];
  }
}
