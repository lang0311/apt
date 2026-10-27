import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import '../../../core/network/api_client.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/models/geo_point.dart';
import '../../place/domain/place.dart';
import '../../course/domain/course_models.dart';

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
  String? lastCourseId;
  String? currentUserId;

  Future<dynamic> get(String path, [Json? query]) => client.run(
    (d) async => (await d.get<dynamic>(path, queryParameters: query)).data,
  );
  Future<dynamic> post(String path, [Json? body]) => client.run(
    (d) async => (await d.post<dynamic>(path, data: body ?? {})).data,
  );
  Future<Json> me() async {
    final data = Map<String, dynamic>.from(await get('/me') as Map);
    currentUserId = (data['user'] as Map)['id'] as String;
    for (final p in data['parties'] as List) {
      partySizes[p['id'] as String] = (p['members'] as List).length;
    }
    for (final p in data['places'] as List) {
      place(Map<String, dynamic>.from(p as Map), saved: true);
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
      categoryKey: category,
      categoryLabel: category.split('>').last.trim(),
      location: p['lat'] is num && p['lon'] is num
          ? GeoPoint((p['lat'] as num).toDouble(), (p['lon'] as num).toDouble())
          : null,
      isSaved: saved || places[id]?['is_saved'] == true,
    );
  }

  /// 카카오 지도 검색. [near]를 주면 그 주변(서버 기준 반경 1.5km)에서 가까운 순.
  Future<List<Place>> search(String q, {GeoPoint? near}) async {
    final data = await get('/places/search', {
      'q': q,
      if (near != null) ...{'lat': near.lat, 'lon': near.lng},
    });
    return [
      for (final p in data['places'] as List)
        place(Map<String, dynamic>.from(p as Map)),
    ];
  }

  Future<String> token(String id) async {
    final p = places[id];
    if (p?['selection_token'] is String) return p!['selection_token'] as String;
    for (final c in courses.values) {
      if ((c['itinerary'] as List).any(
        (p) => (p['key'] ?? p['id']).toString() == id,
      )) {
        final result = await get('/courses/${c['id']}/places/$id/selection');
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

  Course course(Json c) {
    courses[c['id'] as String] = c;
    final time = (c['start_time'] as String?)?.split(':');
    return Course(
      id: c['id'] as String,
      title: (c['title'] ?? '추천 코스').toString(),
      date: DateTime.tryParse((c['date'] ?? '').toString()),
      isParty: c['party_id'] != null,
      partyId: c['party_id'] as String?,
      startTime: time == null
          ? null
          : TimeOfDay(hour: int.parse(time[0]), minute: int.parse(time[1])),
      memberCount: c['party_id'] == null ? 1 : partySizes[c['party_id']] ?? 1,
      canEdit: c['status'] != 'confirmed',
      stops: stops(c),
    );
  }

  List<CourseStop> stops(Json c) => [
    for (final raw in c['itinerary'] as List)
      CourseStop(
        place: place(Map<String, dynamic>.from(raw as Map)),
        source: raw['saved'] == true ? PlaceSource.user : PlaceSource.ai,
        aiReason: raw['saved'] == true ? null : raw['description'] as String?,
      ),
  ];
  /// 사용자가 추천 취소를 눌렀는지. 추천을 새로 시작할 때 끈다.
  bool cancelRequested = false;

  /// 지금 기다리는 추천 job
  String? activeJob;

  /// 추천 job이 끝날 때까지 기다린다. [onStage]에는 서버 stage 값을 그대로 넘긴다.
  /// 취소를 누르면 서버에 취소를 보내고 바로 [CancelledFailure]를 던진다(서버가 멈출 때까지 기다리지 않음).
  Future<Json> poll(String job, {void Function(String stage)? onStage}) async {
    // Reload resumes the same server job; never silently issue a second paid request.
    activeJob = job;
    try {
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
          throw ValidationFailure((data['error'] ?? '추천을 받지 못했어요.').toString());
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

  Future<void> cancelActive() async {
    for (final job in await get('/jobs') as List) {
      await post('/jobs/${job['id']}/cancel');
    }
  }
}
