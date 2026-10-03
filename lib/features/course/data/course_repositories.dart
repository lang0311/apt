import 'package:flutter/material.dart';

import '../../../core/error/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../../../dev/mock/mock_fixtures.dart';
import '../../../dev/mock/mock_store.dart';
import '../domain/course_draft.dart';
import '../domain/course_models.dart';
import '../domain/course_repository.dart';

class MockCourseRepository implements CourseRepository {
  MockCourseRepository(this._store);
  final MockStore _store;

  CourseSummary _summary(Course c) {
    final meta = _store.courseMeta[c.id];
    return CourseSummary(
      id: c.id,
      title: c.title,
      regionLabel: meta?.region,
      placeCount: c.stops.length,
      date: c.date,
      thumbnailUrl: c.stops.isEmpty ? null : c.stops.first.place.imageUrl,
      isParty: c.isParty,
      memberCount: c.memberCount,
      statusLabel: meta?.status,
      tags: meta?.tags ?? const [],
    );
  }

  List<Course> get _newestFirst {
    final list = _store.courses.values.toList();
    list.sort((a, b) => _store.courseCreatedAt[b.id]!.compareTo(_store.courseCreatedAt[a.id]!));
    return list;
  }

  @override
  Future<List<CourseSummary>> fetchMyCourses() => _store.behavior.query(
        () => [for (final c in _newestFirst) if (!c.isParty) _summary(c)],
        empty: () => const [],
      );

  @override
  Future<List<CourseSummary>> fetchPartyCourses() => _store.behavior.query(
        () => [for (final c in _newestFirst) if (c.isParty) _summary(c)],
        empty: () => const [],
      );

  @override
  Future<List<CourseSummary>> fetchActiveCourses() => _store.behavior.query(
        () => [for (final c in _newestFirst.take(1)) _summary(c)],
        empty: () => const [],
      );

  @override
  Future<List<SuggestedCourse>> fetchSuggestedCourses() =>
      _store.behavior.query(() => MockFixtures.suggestedCourses, empty: () => const []);

  @override
  Future<Course> fetchCourse(String courseId) => _store.behavior.query(() {
        final c = _store.courses[courseId];
        if (c == null) throw const NotFoundFailure();
        return c;
      });

  @override
  Future<List<MoodOption>> fetchMoodOptions() => _store.behavior.query(() => MockFixtures.moods);

  @override
  Future<Recommendation> recommend({required CourseDraft draft, List<CourseStop> currentStops = const []}) {
    return _store.behavior.mutate(
      () {
        // 사용자 장소는 현재 순서 그대로 유지, AI 장소만 교체 (가정 A6)
        final userIds = draft.places.map((p) => p.id).toList();
        final excluded = {...userIds, ...draft.rejectedPlaceIds};
        final pool = MockFixtures.aiCandidates.where((c) => !excluded.contains(c.$1)).toList();
        final offset = pool.isEmpty ? 0 : (draft.recommendationRound * 2) % pool.length;
        final picks = [for (var i = 0; i < pool.length && i < 2; i++) pool[(offset + i) % pool.length]];

        final spec = <(String, PlaceSource, String?)>[];
        for (var i = 0; i < userIds.length; i++) {
          spec.add((userIds[i], PlaceSource.user, null));
          // 사용자 장소 사이사이에 AI 추천을 끼운다
          if (i == 1 && picks.isNotEmpty) spec.add((picks[0].$1, PlaceSource.ai, picks[0].$2));
        }
        if (picks.length > 1 || (userIds.length < 2 && picks.isNotEmpty)) {
          final p = picks.length > 1 ? picks[1] : picks[0];
          spec.add((p.$1, PlaceSource.ai, p.$2));
        }
        final isParty = draft.companion == Companion.party;
        return Recommendation(
          recommendationId: 'rec-${draft.recommendationRound}',
          stops: MockFixtures.stopsFor(spec, start: draft.startTime ?? const TimeOfDay(hour: 11, minute: 0)),
          headline: '빈 시간에 어울리는 장소를 찾았어요',
          description: isParty ? '파티 3명의 취향과 현재 동선을 함께 분석했어요.' : '나의 취향과 현재 동선을 함께 분석했어요.',
          preferenceMix: isParty
              ? const [
                  PreferenceShare(label: '카페', percent: 42),
                  PreferenceShare(label: '자연', percent: 35),
                  PreferenceShare(label: '맛집', percent: 23),
                ]
              : const [],
        );
      },
      latency: const Duration(milliseconds: 2400),
    );
  }

  Duration _duration(List<CourseStop> stops) => Duration(minutes: stops.length * 70);

  @override
  Future<Course> createCourse({required CourseDraft draft, required List<CourseStop> stops}) =>
      _store.behavior.mutate(() {
        final id = _store.nextId('k');
        final course = Course(
          id: id,
          title: draft.name,
          date: draft.date,
          startTime: draft.startTime,
          isParty: draft.companion == Companion.party,
          memberCount: draft.companion == Companion.party ? 3 : 1,
          partyId: draft.partyId,
          stops: stops,
          moodKeys: draft.moodKeys,
          totalDuration: _duration(stops),
        );
        _store.courses[id] = course;
        _store.courseCreatedAt[id] = DateTime.now();
        _store.courseMeta[id] = CourseSummaryMeta(
          region: stops.isEmpty ? null : stops.first.place.displayArea.split(' ').first,
          status: course.isParty ? '함께 계획 중' : null,
        );
        return course;
      });

  @override
  Future<Course> updateCourseStops({required String courseId, required List<CourseStop> stops}) =>
      _store.behavior.mutate(() {
        final c = _store.courses[courseId];
        if (c == null) throw const NotFoundFailure();
        final updated = Course(
          id: c.id,
          title: c.title,
          date: c.date,
          startTime: c.startTime,
          isParty: c.isParty,
          memberCount: c.memberCount,
          totalDuration: _duration(stops),
          isShared: c.isShared,
          stops: stops,
          moodKeys: c.moodKeys,
          partyId: c.partyId,
          canEdit: c.canEdit,
        );
        _store.courses[courseId] = updated;
        return updated;
      });
}

// NEEDS BACKEND: 코스 CRUD, 목록 summary, 추천/재추천 API (docs/06 §3)
class ApiCourseRepository implements CourseRepository {
  ApiCourseRepository(this._client);
  // ignore: unused_field
  final ApiClient _client;

  static const _f = NotImplementedFailure('코스');

  @override
  Future<List<CourseSummary>> fetchMyCourses() async => throw _f;
  @override
  Future<List<CourseSummary>> fetchPartyCourses() async => throw _f;
  @override
  Future<List<CourseSummary>> fetchActiveCourses() async => throw _f;
  @override
  Future<List<SuggestedCourse>> fetchSuggestedCourses() async => throw _f;
  @override
  Future<Course> fetchCourse(String courseId) async => throw _f;
  @override
  Future<List<MoodOption>> fetchMoodOptions() async => throw _f;
  @override
  Future<Recommendation> recommend({required CourseDraft draft, List<CourseStop> currentStops = const []}) async => throw _f;
  @override
  Future<Course> createCourse({required CourseDraft draft, required List<CourseStop> stops}) async => throw _f;
  @override
  Future<Course> updateCourseStops({required String courseId, required List<CourseStop> stops}) async => throw _f;
}
