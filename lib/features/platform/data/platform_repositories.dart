import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show DateUtils;

import '../../../core/config/env.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../../auth/data/auth_repositories.dart' show IdSignupRules;
import '../../../core/models/geo_point.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/domain/auth_repository.dart';
import '../../saved/data/api_saved_repository.dart';
import '../../saved/domain/saved_models.dart';
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

class PlatformAuthRepository implements AuthRepository {
  PlatformAuthRepository(this.c);
  final PlatformClient c;
  AuthUser user(dynamic p) => AuthUser(
    id: p['id'] as String,
    nickname: p['name'] as String,
    handle: p['login'] as String?,
  );
  @override
  Future<AuthUser?> restoreSession() async {
    try {
      return user((await c.me())['user']);
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
      final p = await c.post('/auth/login', {
        'login': login.trim(),
        'password': password,
      });
      _start(p);
      return SignedIn(user(p));
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
      final res = await c.client.dio.post<dynamic>('/auth/register', data: {
        'login': login.trim().toLowerCase(),
        'password': password,
        'name': nickname.trim(),
      });
      final p = res.data;
      _start(p);
      return user(p);
    } on DioException catch (e) {
      throw switch (e.response?.statusCode) {
        409 => const ValidationFailure(IdSignupRules.loginTaken, fieldErrors: {'login': IdSignupRules.loginTaken}),
        422 => const ValidationFailure(IdSignupRules.loginInvalid, fieldErrors: {'login': IdSignupRules.loginInvalid}),
        _ => mapDioException(e),
      };
    }
  }

  /// 새 로그인 — 이전 사용자 캐시를 비운다.
  void _start(dynamic p) {
    c.places.clear();
    c.courses.clear();
    c.partySizes.clear();
    c.lastCourseId = null;
    c.currentUserId = p['id'] as String;
  }

  @override
  Future<SignInResult> signInWithEmail({
    required String email,
    required String password,
  }) async => throw const NotImplementedFailure('이메일 로그인');

  @override
  Future<void> signOut() async {
    await c.post('/auth/logout');
    c.places.clear();
    c.courses.clear();
    c.lastCourseId = null;
    c.currentUserId = null;
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
  Future<AuthUser> completeProfile({
    required String nickname,
    String? imagePath,
  }) async => throw const NotImplementedFailure('프로필 수정');
}

class PlatformSavedRepository extends ApiSavedRepository {
  PlatformSavedRepository(this.c) : super(c.client);
  final PlatformClient c;
  @override
  Future<SavedSummary> fetchSummary() async {
    final p = await c.get('/mobile/summary');
    return SavedSummary(
      totalCount: p['saved_count'] as int,
      categories: [
        for (final v in p['categories'] as List)
          PlaceCategory(
            key: v['key'] as String,
            label: v['label'] as String,
            count: v['count'] as int,
          ),
      ],
    );
  }

  @override
  Future<List<SavedPlaceItem>> fetchSavedPlaces(SavedPlaceQuery query) async {
    if (query.collectionId != null) throw const NotImplementedFailure('보관함');
    final data = await c.me();
    return [
      for (final raw in data['places'] as List)
        if ((query.categoryKey == null ||
                raw['category'] == query.categoryKey) &&
            (query.keyword == null ||
                raw['name'].toString().contains(query.keyword!)))
          SavedPlaceItem(
            place: c.place(Map<String, dynamic>.from(raw as Map), saved: true),
          ),
    ];
  }

  @override
  Future<List<SavedPlaceItem>> fetchSavedPlacesNearby(
    GeoPoint center,
    int radiusMeters,
    SavedPlaceQuery query,
  ) async => (await fetchSavedPlaces(query))
      .where(
        (i) =>
            i.place.location != null &&
            center.distanceTo(i.place.location!) <= radiusMeters,
      )
      .toList();
  @override
  Future<List<PlaceCollection>> fetchCollections() async => [];
  @override
  Future<List<String>> fetchPlaceCollectionIds(String placeId) async => [];
  @override
  Future<void> savePlaces({
    required List<String> placeIds,
    required List<String> collectionIds,
  }) async {
    if (collectionIds.isNotEmpty) throw const NotImplementedFailure('보관함');
    for (final id in placeIds) {
      await c.save(id);
    }
  }
}

class PlatformPlaceRepository implements PlaceRepository {
  PlatformPlaceRepository(this.c);
  final PlatformClient c;
  @override
  Future<PlaceDetail> fetchPlace(String placeId) async {
    await c.me();
    final p = c.places[placeId];
    if (p == null) throw const NotFoundFailure();
    return PlaceDetail(place: c.place(p));
  }
}

/// 지도에서 검색하기: GET /places/search. 저장 상태를 맞추려고 먼저 /me를 읽는다.
class PlatformPlaceSearchRepository implements PlaceSearchRepository {
  PlatformPlaceSearchRepository(this.c);
  final PlatformClient c;
  @override
  Future<List<Place>> search(String query, {GeoPoint? near}) async {
    await c.me();
    return c.search(query, near: near);
  }
}

class PlatformCourseRepository implements CourseRepository {
  PlatformCourseRepository(this.c);
  final PlatformClient c;
  CourseSummary summary(Json p) => CourseSummary(
    id: p['id'] as String,
    title: (p['title'] ?? '추천 코스').toString(),
    placeCount: (p['itinerary'] as List).length,
    isParty: p['party_id'] != null,
    date: DateTime.tryParse((p['date'] ?? '').toString()),
    memberCount: p['party_id'] == null ? 1 : c.partySizes[p['party_id']] ?? 1,
  );
  Future<List<Json>> rows([String? party]) async => [
    for (final p
        in await c.get('/courses', party == null ? null : {'party_id': party})
            as List)
      Map<String, dynamic>.from(p as Map),
  ];
  /// 서버는 추천을 받을 때마다 결과를 초안(draft)으로 저장한다. 사용자가 저장한 코스는 확정(confirmed)이라
  /// 목록 · 홈에는 확정한 코스만 쓴다 (저장하지 않은 추천 결과는 보이지 않게).
  static bool isSaved(Json p) => p['status'] == 'confirmed';

  /// 홈 맨 위 카드용: 저장한 코스 중 오늘 이후(오늘 포함) 날짜, 날짜가 없으면 포함 (Mock과 같은 기준, 07 D20)
  static bool isUpcoming(Json p, DateTime today) {
    if (!isSaved(p)) return false;
    final date = DateTime.tryParse((p['date'] ?? '').toString());
    return date == null || !DateUtils.dateOnly(date).isBefore(today);
  }

  Future<List<Json>> partyRows() async {
    final me = await c.me();
    return [
      for (final party in me['parties'] as List) ...await rows(party['id'] as String),
    ];
  }

  @override
  Future<List<CourseSummary>> fetchMyCourses() async => [
    for (final p in await rows()) if (isSaved(p)) summary(p),
  ];
  @override
  Future<List<CourseSummary>> fetchPartyCourses() async => [
    for (final p in await partyRows()) if (isSaved(p)) summary(p),
  ];

  /// 개인 코스(GET /courses)에는 파티 코스가 없어 파티별로 따로 받아 합친다.
  @override
  Future<List<CourseSummary>> fetchActiveCourses() async {
    final today = DateUtils.dateOnly(DateTime.now());
    return [
      for (final p in [...await rows(), ...await partyRows()]) if (isUpcoming(p, today)) summary(p),
    ];
  }
  @override
  Future<List<SuggestedCourse>> fetchSuggestedCourses() async => [];
  @override
  Future<List<MoodOption>> fetchMoodOptions() async => [];
  @override
  Future<Course> fetchCourse(String id) async =>
      c.course(Map<String, dynamic>.from(await c.get('/courses/$id') as Map));
  @override
  Future<Recommendation> recommend({
    required CourseDraft draft,
    List<CourseStop> currentStops = const [],
  }) async {
    final active = await c.get('/jobs') as List;
    if (active.isNotEmpty) {
      return recommendation(await c.poll(active.first['id'] as String));
    }
    final previous = c.lastCourseId;
    final exclusionTokens = <String>[];
    for (final id in draft.rejectedPlaceIds) {
      exclusionTokens.add(await c.token(id));
    }
    final previousAnchors = previous == null
        ? <String>{}
        : {
            for (final p in c.courses[previous]?['itinerary'] as List? ?? [])
              if (p['saved'] == true) (p['key'] ?? p['id']).toString(),
          };
    final sameAnchors =
        previousAnchors.length == draft.placeIds.length &&
        previousAnchors.containsAll(draft.placeIds);
    dynamic started;
    if (previous != null &&
        sameAnchors &&
        draft.recommendationRound > 0 &&
        c.courses[previous]?['status'] != 'confirmed') {
      var old = c.courses[previous]!;
      final removed = [
        for (final p in old['itinerary'] as List)
          if (draft.rejectedPlaceIds.contains((p['key'] ?? p['id']).toString()))
            p,
      ];
      if (removed.length == 1 &&
          currentStops.length == (old['itinerary'] as List).length - 1) {
        started = await c.post('/courses/$previous/replace', {
          'revision': old['revision'],
          'place_key': removed.first['key'],
        });
        return recommendation(await c.poll(started['job_id'] as String));
      }
      // Persist local removals before replacement so the server retains exclusions.
      for (final p in List<dynamic>.from(old['itinerary'] as List)) {
        final id = (p['key'] ?? p['id']).toString();
        if (draft.rejectedPlaceIds.contains(id)) {
          old = Map<String, dynamic>.from(
            await c.client.run(
                  (d) async => (await d.delete<dynamic>(
                    '/courses/$previous/places',
                    data: {'revision': old['revision'], 'place_key': id},
                  )).data,
                )
                as Map,
          );
        }
      }
      c.courses[previous] = old;
      started = await c.post('/courses/$previous/replace', {
        'revision': old['revision'],
      });
    } else {
      if (draft.places.isEmpty || draft.places.length > 6) {
        throw const ValidationFailure('필수 장소를 1~6곳 선택해주세요.');
      }
      final tokens = <String>[];
      for (final p in draft.places) {
        tokens.add(await c.token(p.id));
      }
      final address = draft.places.first.address.split(' ').take(2).join(' ');
      started = await c.post('/jobs', {
        'area': address.isEmpty ? '서울 마포구' : address,
        'place_tokens': tokens,
        'excluded_place_tokens': exclusionTokens,
        'place_count': (draft.places.length + 3).clamp(1, 6),
        'party_id': draft.companion == Companion.party ? draft.partyId : null,
      });
    }
    return recommendation(await c.poll(started['job_id'] as String));
  }

  Recommendation recommendation(Json p) => Recommendation(
    recommendationId: p['id'] as String,
    stops: c.stops(p),
    headline: '코스를 확인해주세요',
    description: [
      p['recommendation_reason'],
      ...(p['warnings'] as List? ?? []),
    ].whereType<String>().join('\n'),
  );
  @override
  Future<Course> createCourse({
    required CourseDraft draft,
    required List<CourseStop> stops,
  }) async {
    final id = c.lastCourseId;
    if (id == null) throw const ValidationFailure('추천을 먼저 받아주세요.');
    final old = c.courses[id]!;
    final changed = Map<String, dynamic>.from(
      await c.post('/mobile/courses/$id', {
            'revision': old['revision'],
            'title': draft.name,
            'date': draft.date?.toIso8601String(),
            'start_time': draft.startTime == null
                ? null
                : '${draft.startTime!.hour.toString().padLeft(2, '0')}:${draft.startTime!.minute.toString().padLeft(2, '0')}',
            'ordered_keys': stops.map((s) => s.place.id).toList(),
          })
          as Map,
    );
    final confirmed = await c.post('/courses/$id/confirm', {
      'revision': changed['revision'],
    });
    return c.course(Map<String, dynamic>.from(confirmed as Map));
  }

  /// 차단 목록. 서버는 차단한 날을 주지 않는다 (NEEDS BACKEND).
  @override
  Future<List<BlockedPlace>> fetchBlockedPlaces() async => [
    for (final raw in await c.get('/me/blocks') as List)
      BlockedPlace(place: c.place(Map<String, dynamic>.from(raw as Map))),
  ];

  /// 서버에는 따로 차단하는 API가 없고, 코스에서 장소를 뺄 때 `block_future`로만 차단한다.
  /// 그 장소가 든 추천 코스를 찾아 서버에서도 빼면서 차단한다. 코스가 없으면 NEEDS BACKEND.
  @override
  Future<void> blockPlace(String placeId) async {
    for (final course in [?c.lastCourseId, ...c.courses.keys]) {
      final old = c.courses[course];
      if (old == null || old['status'] == 'confirmed') continue;
      final hit = (old['itinerary'] as List).any((p) => (p['key'] ?? p['id']).toString() == placeId);
      if (!hit) continue;
      c.courses[course] = Map<String, dynamic>.from(
        await c.client.run(
              (d) async => (await d.delete<dynamic>(
                '/courses/$course/places',
                data: {'revision': old['revision'], 'place_key': placeId, 'block_future': true},
              )).data,
            )
            as Map,
      );
      return;
    }
    throw const NotImplementedFailure('코스 밖에서 장소 차단');
  }

  @override
  Future<void> unblockPlace(String placeId) =>
      c.client.run((d) => d.delete<dynamic>('/me/blocks/$placeId'));

  @override
  Future<Course> updateCourseStops({
    required String courseId,
    required List<CourseStop> stops,
  }) async {
    final old =
        c.courses[courseId] ??
        Map<String, dynamic>.from(await c.get('/courses/$courseId') as Map);
    return c.course(
      Map<String, dynamic>.from(
        await c.post('/mobile/courses/$courseId', {
              'revision': old['revision'],
              'ordered_keys': stops.map((s) => s.place.id).toList(),
            })
            as Map,
      ),
    );
  }
}

class PlatformHomeRepository implements HomeRepository {
  PlatformHomeRepository(this.c);
  final PlatformClient c;
  @override
  Future<HomeStats> fetchStats() async {
    final p = await c.get('/mobile/summary');
    return HomeStats(
      savedPlaceCount: p['saved_count'] as int,
      activeCourseCount: p['active_course_count'] as int,
      recentExtractionCount: 0,
    );
  }

  @override
  Future<List<Place>> fetchTrendingPlaces() async => [];
}

class PlatformMyRepository implements MyRepository {
  PlatformMyRepository(this.c);
  final PlatformClient c;
  @override
  Future<MyProfile> fetchProfile() async {
    final p = await c.get('/mobile/summary');
    return MyProfile(
      nickname: p['name'] as String,
      savedPlaceCount: p['saved_count'] as int,
      createdCourseCount: p['created_course_count'] as int,
      joinedCourseCount: p['joined_course_count'] as int,
    );
  }
}

class PlatformPreferenceRepository implements PreferenceRepository {
  PlatformPreferenceRepository(this.c);
  final PlatformClient c;
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

class PlatformPartyRepository implements PartyRepository {
  PlatformPartyRepository(this.c);
  final PlatformClient c;
  @override
  Future<Party> createParty() async {
    final p = await c.post('/parties', {'name': '함께 만드는 코스'});
    return fetchParty(p['id'] as String);
  }

  @override
  Future<Party> fetchParty(String id) async {
    final p = await c.get('/parties/$id');
    return Party(
      id: id,
      members: [
        for (final m in p['members'] as List)
          PartyMember(
            id: m['id'] as String,
            nickname: m['name'] as String,
            isMe: m['id'] == c.currentUserId,
          ),
      ],
    );
  }

  @override
  Future<InviteLink> createInviteLink(String id) async {
    final p = await c.post('/parties/$id/invites');
    // 브라우저는 지금 주소, 앱은 서버가 띄워 주는 웹 앱 주소로 만든다. NEEDS BACKEND: 정식 초대 링크 도메인·앱 링크
    final base = kIsWeb ? Uri.base : Uri.parse(Env.apiBaseUrl).replace(path: '/mobile-app/');
    return InviteLink(url: base.replace(fragment: '/invites/${p['code']}').toString());
  }

  @override
  Future<Invitation> fetchInvitation(String token) async {
    final p = await c.get('/mobile/invites/$token');
    return Invitation(
      token: token,
      inviterName: p['inviter'] as String,
      courseTitle: p['name'] as String,
      memberCount: p['member_count'] as int,
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
    await c.post('/parties/join', {'code': token});
  }

  @override
  Future<void> declineInvitation(String token) async {}
}

/// 팀 서버에는 링크 추출 기능이 없다 (NEEDS BACKEND). 추출 기록은 없는 것으로 보고 빈 목록을 준다 —
/// 홈의 "최근 저장한 곳"이 오류 칸 대신 숨겨진다. Mock 결과로 대신하지 않는다.
class PlatformExtractionRepository implements ExtractionRepository {
  PlatformExtractionRepository(this.c);
  final PlatformClient c;

  @override
  Future<ExtractionResult> extract(String url) async => throw const NotImplementedFailure('링크로 장소 찾기');

  /// 서버에는 추출 기록이 없어, 저장 장소(/me)를 저장한 시각(saved_at) 순으로 대신 쓴다 (홈 '최근 저장한 곳').
  @override
  Future<List<RecentExtraction>> fetchRecent({int limit = 2}) async => recentFrom(
        [for (final p in (await c.me())['places'] as List) Map<String, dynamic>.from(p as Map)],
        limit: limit,
      );

  List<RecentExtraction> recentFrom(List<Json> places, {required int limit}) {
    final dated = [
      for (final p in places)
        if (DateTime.tryParse((p['saved_at'] ?? '').toString()) case final at?) (p, at.toLocal()),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    return [
      for (final (p, at) in dated.take(limit))
        RecentExtraction(place: c.place(p, saved: true), sourceUrl: (p['place_url'] ?? '').toString(), extractedAt: at),
    ];
  }
}
