import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/course/domain/course_models.dart';
import '../../features/place/domain/place.dart';
import '../../features/saved/domain/saved_models.dart';
import 'mock_behavior.dart';
import 'mock_fixtures.dart';

/// Mock "서버" 상태. 앱 실행 동안 메모리에 유지되어 저장/생성 결과가 다른 화면에 반영된다.
/// (집계·카운트는 실제로는 서버가 한다. 여기서 계산하는 것은 서버 흉내일 뿐이다.)
class MockStore {
  MockStore() {
    savedIds.addAll(MockFixtures.savedPlaceIds);
    for (final c in MockFixtures.collections) {
      collections[c.id] = c;
      members[c.id] = [...?MockFixtures.collectionMembers[c.id]];
    }
    _seedCourses();
  }

  final behavior = MockBehavior.fromEnv();

  final Set<String> savedIds = {};
  final Map<String, PlaceCollection> collections = {};
  final Map<String, List<String>> members = {};
  final Map<String, Course> courses = {};
  final Map<String, DateTime> courseCreatedAt = {};
  Set<String> preferenceKeys = {...MockFixtures.selectedPreferenceKeys};
  bool autoAnalysis = true;
  int _seq = 100;

  String nextId(String prefix) => '$prefix${_seq++}';

  Place placeWithSaved(String id) {
    final p = MockFixtures.place(id);
    return p.copyWith(isSaved: savedIds.contains(id));
  }

  List<Place> get savedPlaces => [for (final id in savedIds) placeWithSaved(id)];

  PlaceCollection collectionView(String id) {
    final c = collections[id]!;
    final ids = members[id] ?? const [];
    return PlaceCollection(
      id: c.id,
      name: c.name,
      placeCount: ids.length,
      thumbnailUrls: [for (final pid in ids.take(3)) MockFixtures.place(pid).imageUrl!],
      updatedAt: c.updatedAt,
      createdAt: c.createdAt,
    );
  }

  void touchCollection(String id) {
    final c = collections[id]!;
    collections[id] = PlaceCollection(id: c.id, name: c.name, placeCount: 0, updatedAt: DateTime.now(), createdAt: c.createdAt);
  }

  void _seedCourses() {
    final now = DateTime(2026, 10, 4);
    void add(Course c, {CourseSummaryMeta? meta}) {
      courses[c.id] = c;
      courseCreatedAt[c.id] = now;
      if (meta != null) courseMeta[c.id] = meta;
    }

    add(
      Course(
        id: 'k1',
        title: '서울 카페 투어',
        date: DateTime(2026, 10, 12),
        startTime: const TimeOfDay(hour: 11, minute: 0),
        stops: MockFixtures.stopsFor([
          ('p1', PlaceSource.user, null),
          ('p2', PlaceSource.user, null),
          ('p5', PlaceSource.ai, '산책 취향 보완'),
          ('p4', PlaceSource.user, null),
        ]),
        totalDuration: const Duration(hours: 5, minutes: 20),
        moodKeys: const {'emotional', 'walk'},
      ),
      meta: const CourseSummaryMeta(region: '서울', tags: ['카페', '감성']),
    );
    add(
      Course(
        id: 'k2',
        title: '성수동 하루 코스',
        date: DateTime(2026, 10, 5),
        startTime: const TimeOfDay(hour: 12, minute: 0),
        stops: MockFixtures.stopsFor([
          ('p3', PlaceSource.user, null),
          ('p9', PlaceSource.ai, '요즘 인기 전시'),
          ('p2', PlaceSource.user, null),
        ], start: const TimeOfDay(hour: 12, minute: 0)),
        totalDuration: const Duration(hours: 4),
      ),
      meta: const CourseSummaryMeta(region: '서울', tags: ['맛집', '전시']),
    );
    add(
      Course(
        id: 'k3',
        title: '부산 바다 여행',
        date: DateTime(2026, 9, 20),
        stops: MockFixtures.stopsFor([
          ('p8', PlaceSource.user, null),
          ('p7', PlaceSource.user, null),
        ]),
        totalDuration: const Duration(hours: 6),
      ),
      meta: const CourseSummaryMeta(region: '부산', tags: ['바다', '카페', '힐링']),
    );
    add(
      Course(
        id: 'k4',
        title: '가을 제주도 여행',
        date: DateTime(2026, 11, 2),
        isParty: true,
        memberCount: 3,
        partyId: 'party1',
        stops: MockFixtures.stopsFor([
          ('p1', PlaceSource.user, null),
          ('p6', PlaceSource.ai, '남는 50분 활용'),
          ('p4', PlaceSource.user, null),
        ]),
        totalDuration: const Duration(hours: 5),
      ),
      meta: const CourseSummaryMeta(region: '제주', tags: ['바다'], status: '함께 계획 중'),
    );
  }

  final Map<String, CourseSummaryMeta> courseMeta = {};
}

/// Mock 전용 코스 목록 메타 (서버 summary 흉내)
class CourseSummaryMeta {
  const CourseSummaryMeta({this.region, this.tags = const [], this.status});
  final String? region;
  final List<String> tags;
  final String? status;
}

final mockStoreProvider = Provider<MockStore>((ref) => MockStore());
