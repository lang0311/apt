import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/repositories.dart';
import '../domain/course_models.dart';

final myCoursesProvider = FutureProvider.autoDispose<List<CourseSummary>>(
  (ref) => ref.watch(courseRepositoryProvider).fetchMyCourses(),
);

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

final moodOptionsProvider = FutureProvider.autoDispose<List<MoodOption>>(
  (ref) => ref.watch(courseRepositoryProvider).fetchMoodOptions(),
);

/// 코스 생성/수정 후 목록·상세를 새로 고친다.
void invalidateCourseData(WidgetRef ref) {
  ref.invalidate(myCoursesProvider);
  ref.invalidate(partyCoursesProvider);
  ref.invalidate(activeCoursesProvider);
  ref.invalidate(courseDetailProvider);
}
