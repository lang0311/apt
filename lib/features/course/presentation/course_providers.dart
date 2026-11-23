import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import '../../../app/di/repositories.dart';
import '../domain/course_models.dart';

final myCoursesProvider = FutureProvider.autoDispose<List<CourseSummary>>((ref) => ref.watch(courseRepositoryProvider).fetchMyCourses());

final partyCoursesProvider = FutureProvider.autoDispose<List<CourseSummary>>(
  (ref) => ref.watch(courseRepositoryProvider).fetchPartyCourses(),
);

/// 홈 "내 코스 바로가기"
final activeCoursesProvider = FutureProvider.autoDispose<List<CourseSummary>>(
  (ref) => ref.watch(courseRepositoryProvider).fetchActiveCourses(),
);

final suggestedCoursesProvider = FutureProvider.autoDispose<List<SuggestedCourse>>(
  (ref) => ref.watch(courseRepositoryProvider).fetchSuggestedCourses(),
);

final courseDetailProvider = FutureProvider.autoDispose.family<Course, String>(
  (ref, id) => ref.watch(courseRepositoryProvider).fetchCourse(id),
);

final moodOptionsProvider = FutureProvider.autoDispose<List<MoodOption>>((ref) => ref.watch(courseRepositoryProvider).fetchMoodOptions());

/// 코스 생성/수정 후 목록·상세를 새로 고친다.
void invalidateCourseData(WidgetRef ref) => _courseData.forEach(ref.invalidate);

/// 화면이 사라진 뒤에도(저장 중 뒤로 가기 등) 쓸 수 있게 컨테이너로 새로 고친다.
void invalidateCourseDataIn(ProviderContainer container) => _courseData.forEach(container.invalidate);

final _courseData = <ProviderOrFamily>[
  myCoursesProvider,
  partyCoursesProvider,
  activeCoursesProvider,
  courseDetailProvider,
  unsavedRecommendationProvider,
];

/// 홈 맨 위 "저장 안 한 추천이 있어요" (13번). 못 읽으면 안내만 빼고 홈은 그대로 둔다
final unsavedRecommendationProvider = FutureProvider.autoDispose<UnsavedRecommendation?>((ref) async {
  try {
    return await ref.watch(courseRepositoryProvider).fetchUnsavedRecommendation();
  } catch (_) {
    return null;
  }
});

/// 오늘 추천 사용량 (12번, 3/4). 못 읽으면 막지 않는다 — 한도에 걸리면 추천 중에 따로 안내한다
final recommendationQuotaProvider = FutureProvider.autoDispose<RecommendationQuota?>((ref) async {
  try {
    return await ref.watch(courseRepositoryProvider).fetchRecommendationQuota();
  } catch (_) {
    return null;
  }
});

/// 추천하지 않는 장소 (마이 → 추천하지 않는 장소)
final blockedPlacesProvider = FutureProvider.autoDispose<List<BlockedPlace>>(
  (ref) => ref.watch(courseRepositoryProvider).fetchBlockedPlaces(),
);
