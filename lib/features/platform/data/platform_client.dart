import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import '../../../core/utils/formatters.dart';
import '../../../core/network/api_client.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/models/geo_point.dart';
import '../../place/domain/place.dart';
import '../../place/domain/place_timing.dart';
import '../../course/domain/course_models.dart';
import '../../course/domain/course_schedule.dart';

typedef Json = Map<String, dynamic>;
final platformClientProvider = Provider(
  (ref) => PlatformClient(ref.watch(apiClientProvider)),
);

class PlatformClient {
  PlatformClient(this.client);
  final ApiClient client;
  final Map<String, Json> places = {};
  final Map<String, Json> courses = {};
  final Map<String, int> partySizes = {};

  /// 파티 id → 파티장 id. GET /me의 parties에만 온다(GET /parties/{id}에는 없음).
  final Map<String, String> partyOwners = {};
  String? lastCourseId;
  String? currentUserId;

  Future<dynamic> get(String path, [Json? query]) => client.run(
    (d) async => (await d.get<dynamic>(path, queryParameters: query)).data,
  );
  Future<dynamic> post(String path, [Json? body]) => client.run(
    (d) async => (await d.post<dynamic>(path, data: body ?? {})).data,
  );
  Future<dynamic> delete(String path, [Json? body]) => client.run(
    (d) async => (await d.delete<dynamic>(path, data: body)).data,
  );
  Future<Json> me() async {
    final data = Map<String, dynamic>.from(await get('/me') as Map);
    currentUserId = (data['user'] as Map)['id'] as String;
    for (final party in data['parties'] as List) {
      partySizes[party['id'] as String] = (party['members'] as List).length;
      if (party['owner'] case final String owner) partyOwners[party['id'] as String] = owner;
    }
    for (final saved in data['places'] as List) {
      place(Map<String, dynamic>.from(saved as Map), saved: true);
    }
    return data;
  }

  Place place(Json p, {bool saved = false}) {
    final id = (p['key'] ?? p['id'] ?? p['place_url']).toString();
    places[id] = {...?places[id], ...p, if (saved) 'is_saved': true};
    final category = (p['category'] ?? p['category_group_name'] ?? '')
        .toString();
    return Place(
      id: id,
      name: p['name'] as String,
      address: (p['road_address'] ?? p['address'] ?? '').toString(),
      // 동 이름은 지번 주소(`address`)에만 있어서 짧은 동네 표기는 지번 주소로 뽑는다 ('상수동'). 장소 상세의 주소 줄은 도로명
      areaLabel: _text(p['address']),
      categoryKey: category,
      categoryLabel: categoryShortLabel(category),
      location: p['lat'] is num && p['lon'] is num
          ? GeoPoint((p['lat'] as num).toDouble(), (p['lon'] as num).toDouble())
          : null,
      keywords: _tags(p['attribute_profile']),
      phone: _text(p['phone']),
      mapUrl: _webUrl(p['place_url']),
      // 추천 일정에만 온다. 저장 목록 등 다른 응답에는 없어서 앞서 받은 값(places 캐시)을 쓴다
      timing: PlaceTiming.fromJson(p['temporal'] ?? places[id]?['temporal']),
      isSaved: saved || places[id]?['is_saved'] == true,
    );
  }

  /// 서버가 근거와 함께 뽑은 장소 태그(`attribute_profile.tags[].tag`)를 키워드로 쓴다.
  /// 추천에 쓰인 적 없는 장소는 태그가 없다(서버가 추천 과정에서만 만든다).
  static List<String> _tags(Object? profile) {
    final tags = profile is Map ? profile['tags'] : null;
    if (tags is! List) return const [];
    return {
      for (final tag in tags)
        if (tag is Map && _text(tag['tag']) != null) _text(tag['tag'])!,
    }.toList();
  }

  static String? _text(Object? value) {
    final text = value is String ? value.trim() : '';
    return text.isEmpty ? null : text;
  }

  /// http(s) 주소만 링크로 쓴다
  static String? _webUrl(Object? value) {
    final text = _text(value);
    final uri = text == null ? null : Uri.tryParse(text);
    return uri != null && (uri.isScheme('http') || uri.isScheme('https')) && uri.host.isNotEmpty ? text : null;
  }

  /// 카카오 지도 검색. [near]를 주면 그 주변(서버 기준 반경 1.5km)에서 가까운 순.
  /// 검색어가 있으면 이름 검색(전국, [near]가 있으면 그 주변 1.5km), 비어 있으면 [category]로 [near] 주변 1.5km (최대 15곳)
  Future<List<Place>> search(String q, {GeoPoint? near, String? category}) async {
    final data = await get('/places/search', {
      'q': q,
      if (near != null) ...{'lat': near.lat, 'lon': near.lng},
      'category': ?category,
    });
    return [
      for (final found in data['places'] as List)
        place(Map<String, dynamic>.from(found as Map)),
    ];
  }

  Future<String> token(String id) async {
    final cached = places[id];
    if (cached?['selection_token'] is String) return cached!['selection_token'] as String;
    for (final course in courses.values) {
      final inCourse = (course['itinerary'] as List).any((stop) => (stop['key'] ?? stop['id']).toString() == id);
      if (inCourse) {
        final result = await get('/courses/${course['id']}/places/$id/selection');
        places[id]?['selection_token'] = result['token'];
        return result['token'] as String;
      }
    }
    await me();
    if (places[id]?['selection_token'] is String) {
      return places[id]!['selection_token'] as String;
    }
    throw const ValidationFailure('장소를 다시 검색하거나 저장 목록을 새로고침해주세요.');
  }

  Future<void> save(String id) async {
    await post('/me/places', {'token': await token(id)});
  }

  /// 저장 해제. 서버는 저장 장소를 `key`로 지운다. 검색 결과에서 온 장소는 id가 카카오 장소 id라서
  /// 같은 `place_url`의 저장 기록에서 key를 찾는다. 장소 토큰은 캐시에 남겨 둬서 바로 다시 저장할 수 있다.
  Future<void> unsave(String id) async {
    final cached = places[id];
    final url = cached?['place_url'];
    final sameSaved = [
      for (final entry in places.entries)
        if (entry.value['key'] is String && (entry.key == id || (url is String && url.isNotEmpty && entry.value['place_url'] == url)))
          entry,
    ];
    final key = sameSaved.isEmpty ? id : sameSaved.first.value['key'] as String;
    await delete('/me/places/$key');
    cached?['is_saved'] = false;
    for (final entry in sameSaved) {
      entry.value['is_saved'] = false;
    }
  }

  Course course(Json json) {
    courses[json['id'] as String] = json;
    final time = (json['start_time'] as String?)?.split(':');
    return Course(
      id: json['id'] as String,
      title: (json['title'] ?? '추천 코스').toString(),
      date: DateTime.tryParse((json['date'] ?? '').toString()),
      isParty: json['party_id'] != null,
      partyId: json['party_id'] as String?,
      startTime: time == null
          ? null
          : TimeOfDay(hour: int.parse(time[0]), minute: int.parse(time[1])),
      memberCount: json['party_id'] == null ? 1 : partySizes[json['party_id']] ?? 1,
      // NEEDS BACKEND: 서버가 확정한 코스의 수정을 409로 막아 저장한 코스는 편집을 숨긴다.
      // 확정 후 수정이 허용되면 연다 (07 §3, 06 §7)
      canEdit: json['status'] != 'confirmed',
      stops: stops(json),
      taste: appliedTaste(json['taste_profile'], itinerary: json['itinerary'] as List?),
      schedule: estimatedSchedule(json['taste_profile']),
      ownerId: json['owner'] as String?,
    );
  }

  /// 서버 예상 일정 (`taste_profile.route_optimization`, 팀 c29137a, 21번).
  /// 순서 최적화를 건너뛴 코스(`method: unchanged`)와 예전 코스는 일정이 없어 null
  static EstimatedSchedule? estimatedSchedule(Object? tasteProfile) {
    final audit = tasteProfile is Map ? tasteProfile['route_optimization'] : null;
    if (audit is! Map) return null;
    final start = _clock(audit['start_time']);
    final rows = audit['estimated_schedule'];
    if (start == null || rows is! List || rows.isEmpty) return null;
    final stops = <({String name, TimeOfDay arrival})>[];
    for (final row in rows) {
      final arrival = row is Map ? _clock(row['estimated_arrival']) : null;
      if (arrival == null) return null;
      stops.add((name: (row as Map)['name'].toString(), arrival: arrival));
    }
    return EstimatedSchedule(start: start, stops: stops, usedDefaultStart: audit['used_default_start'] == true);
  }

  /// 'HH:mm' → TimeOfDay
  static TimeOfDay? _clock(Object? value) {
    final parts = (value ?? '').toString().split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]), m = int.tryParse(parts[1]);
    return h == null || m == null ? null : TimeOfDay(hour: h, minute: m);
  }

  /// 반영한 취향 한 줄에 쓸 단어 (07 D46). 서버 `taste_profile.keywords`를 서버 순서대로 쓰되,
  /// 관심 주제(`interest_theme` · `specific_interest`)와 업종(`category`)만 두고 분위기 단어는 뺀다.
  /// 업종 중 지도 분류의 넓은 이름(여행 · 관광명소 등)과 경로(`>`)도 뺀다. 서버 `summary` 문장은 분석 말투라 쓰지 않는다.
  /// 파티 코스는 2명 이상이 공유한 단어(`shared_by` ≥ 2)만 쓰고, 그런 단어가 없으면 단어 없이 인원만 보여 준다.
  /// 취향 단어가 아예 없으면(저장 기록이 없는 파티 등) 줄을 띄우지 않는다.
  static AppliedTaste? appliedTaste(Object? profile, {List? itinerary}) {
    if (profile is! Map) return null;
    final size = profile['group_size'];
    final members = size is int && size > 1 ? size : 1;
    final words = <String>[];
    var hasTaste = false;
    for (final keyword in profile['keywords'] as List? ?? const []) {
      if (keyword is! Map) continue;
      final word = (keyword['category'] ?? '').toString().trim();
      final dimension = (keyword['dimension'] ?? 'category').toString();
      if (!_tasteDimensions.contains(dimension)) continue;
      if (word.isEmpty || word.contains('>') || _broadCategories.contains(word) || words.contains(word)) continue;
      hasTaste = true;
      final shared = keyword['shared_by'];
      if (members > 1 && !(shared is int && shared >= 2)) continue;
      words.add(word);
    }
    if (!hasTaste) return null;
    final (matches, gaps) = members > 1 ? _blend(profile['group_blend'], itinerary ?? const []) : (const <String, List<String>>{}, const <TasteGap>[]);
    return AppliedTaste(words: words, memberCount: members, matches: matches, gaps: gaps);
  }

  /// 파티 코스에서 장소마다 강하게 맞는 파티원 (07 D46). 서버 `group_blend.per_user[id].strong_match_places`는
  /// 내가 고른 장소와 AI 장소를 모두 담고, 장소를 이름으로만 알려 줘서 일정 이름과 맞춘다.
  /// 일정에 같은 이름이 둘 이상이면 어느 쪽인지 모르므로 뺀다.
  static (Map<String, List<String>>, List<TasteGap>) _blend(Object? blend, List itinerary) {
    final perUser = blend is Map ? blend['per_user'] : null;
    if (perUser is! Map) return (const {}, const []);
    final idsByName = <String, List<String>>{};
    for (final stop in itinerary) {
      if (stop is! Map) continue;
      final name = (stop['name'] ?? '').toString().trim();
      final id = (stop['key'] ?? stop['id'] ?? stop['place_url'])?.toString();
      if (name.isEmpty || id == null) continue;
      (idsByName[name] ??= []).add(id);
    }
    final matches = <String, List<String>>{};
    final gaps = <TasteGap>[];
    for (final MapEntry(key: member, value: info) in perUser.entries) {
      if (info is! Map) continue;
      if (info['status'] == 'insufficient_history') {
        gaps.add(TasteGap(memberId: member.toString(), noHistory: true));
        continue;
      }
      if (info['represented'] == false) gaps.add(TasteGap(memberId: member.toString(), noHistory: false));
      for (final name in info['strong_match_places'] as List? ?? const []) {
        final ids = idsByName[name.toString().trim()];
        if (ids == null || ids.length != 1) continue;
        (matches[ids.single] ??= []).add(member.toString());
      }
    }
    return (matches, gaps);
  }

  static const _tasteDimensions = {'interest_theme', 'specific_interest', 'category'};

  /// 카카오 지도 대분류처럼 너무 넓어서 취향으로 읽히지 않는 이름
  static const _broadCategories = {'여행', '관광명소', '관광,명소', '음식점', '문화시설', '문화,예술', '쇼핑', '서비스,산업', '가정,생활'};

  List<CourseStop> stops(Json course) => [
    for (final stop in course['itinerary'] as List)
      CourseStop(
        place: place(Map<String, dynamic>.from(stop as Map)),
        source: stop['saved'] == true ? PlaceSource.user : PlaceSource.ai,
        aiReason: stop['saved'] == true ? null : _reason(stop['description']),
        evidence: stop['saved'] == true ? const [] : evidence(stop['web_evidence']),
      ),
  ];

  /// 서버 `web_evidence` [{url, quote, published, ...}] → 글 목록. 주소가 없거나 같은 주소는 뺀다 (2번)
  static List<PlaceEvidence> evidence(Object? raw) {
    final seen = <String>{};
    return [
      for (final row in raw is List ? raw : const [])
        if (row is Map && row['url'] is String && (row['url'] as String).isNotEmpty && seen.add(row['url'] as String))
          PlaceEvidence(
            url: row['url'] as String,
            quote: _reason(row['quote']) ?? _reason(row['text']),
            publishedAt: DateTime.tryParse((row['published'] ?? '').toString()),
          ),
    ];
  }

  /// 서버가 추천 이유를 빈 문자열로 줄 수 있다(팀 8b58c46~). 빈 값은 null로 넘겨 '추천 이유 보기' 줄이 안 뜨게 한다 (07 D40).
  static String? _reason(Object? description) {
    final text = description is String ? description.trim() : '';
    return text.isEmpty ? null : text;
  }

  /// 사용자가 추천 취소를 눌렀는지. 추천을 새로 시작할 때 끈다.
  bool cancelRequested = false;

  /// 지금 기다리는 추천 job
  String? activeJob;

  /// 추천 job이 끝날 때까지 기다린다. [onStage]에는 서버 stage 값을 그대로 넘긴다.
  /// 취소를 누르면 서버에 취소를 보내고 바로 [CancelledFailure]를 던진다(서버가 멈출 때까지 기다리지 않음).
  Future<Json> poll(String job, {void Function(String stage)? onStage}) async {
    // 새로고침해도 같은 서버 job을 이어서 기다린다. 비용이 드는 추천 요청을 몰래 다시 보내지 않는다.
    activeJob = job;
    try {
      // 요청을 보낸 뒤 job 번호를 받기 전에 취소를 눌렀으면 여기서 서버에 알린다
      // (그때는 번호를 몰라 cancelRecommendation이 취소를 보내지 못했다).
      if (cancelRequested) {
        await post('/jobs/$job/cancel');
        throw const CancelledFailure();
      }
      for (var i = 0; i < 1200; i++) {
        if (cancelRequested) throw const CancelledFailure();
        final data = Map<String, dynamic>.from(await get('/jobs/$job') as Map);
        if (data['status'] == 'completed') {
          final result = Map<String, dynamic>.from(data['result'] as Map);
          course(result);
          lastCourseId = result['id'] as String;
          return result;
        }
        if (data['status'] == 'cancelled' || cancelRequested) throw const CancelledFailure();
        if (data['status'] == 'failed') {
          final error = (data['error'] ?? '추천을 받지 못했어요.').toString();
          // 팀 서버 platform_store.reserve의 429 문장 (12번). 초기화 시각은 화면에서 /me/usage로 다시 읽는다
          if (error.contains('한도에 도달')) throw const QuotaExceededFailure();
          throw ValidationFailure(error);
        }
        if (data['stage'] != null) onStage?.call(data['stage'].toString());
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      await post('/jobs/$job/cancel');
      throw const TimeoutFailure('추천 작업을 취소 요청했어요. 진행 중 요청의 비용은 발생할 수 있어요.');
    } finally {
      if (activeJob == job) activeJob = null;
    }
  }

  /// 진행 중인 추천을 취소한다. job을 시작하기 전이면 시작하지 않게 표시만 한다.
  Future<void> cancelRecommendation() async {
    cancelRequested = true;
    final job = activeJob;
    if (job != null) await post('/jobs/$job/cancel');
  }

  /// 취소 중인 job이 끝날 때까지 기다린다. 서버는 그동안 새 추천을 409로 막는다.
  Future<void> waitUntilSettled(String job) async {
    for (var i = 0; i < 300; i++) {
      if (cancelRequested) throw const CancelledFailure();
      final data = Map<String, dynamic>.from(await get('/jobs/$job') as Map);
      if (!const {'queued', 'running', 'cancelling'}.contains(data['status'])) return;
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    throw const TimeoutFailure('이전 추천을 멈추는 중이에요. 잠시 후 다시 시도해주세요.');
  }
}
