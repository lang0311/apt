import 'course_draft.dart';
import 'course_models.dart';

abstract interface class CourseRepository {
  Future<List<CourseSummary>> fetchMyCourses();

  /// 모임/파티 코스 (코스 목록의 두 번째 탭)
  Future<List<CourseSummary>> fetchPartyCourses();

  /// 홈 "내 코스 바로가기" (진행 중 코스)
  Future<List<CourseSummary>> fetchActiveCourses();

  Future<List<SuggestedCourse>> fetchSuggestedCourses();

  Future<Course> fetchCourse(String courseId);

  Future<List<MoodOption>> fetchMoodOptions();

  /// AI 추천 / 재추천.
  /// [currentStops]: 4/4 루프에서 사용자가 편집한 현재 코스 (재추천 기준).
  /// [CourseDraft.rejectedPlaceIds]는 이번 코스에서만 뺀 장소, 차단한 장소는 서버가 계정 기준으로 뺀다.
  /// NEEDS BACKEND: 입력 형식, 재추천 의미(AI 장소만 교체 vs 전체 재생성), 제외 목록 지원,
  /// 동기/비동기 응답, 횟수 제한 (docs/06 §3).
  Future<Recommendation> recommend({required CourseDraft draft, List<CourseStop> currentStops = const []});

  Future<Course> createCourse({required CourseDraft draft, required List<CourseStop> stops});

  /// 완성된 코스 수정 (순서 편집, 장소 추가, 재추천 반영)
  Future<Course> updateCourseStops({required String courseId, required List<CourseStop> stops});

  /// 추천하지 않는 장소 (계정 단위). NEEDS BACKEND: 사용자별 차단 목록 저장·조회·해제, 추천이 이 목록을 빼는지
  Future<List<BlockedPlace>> fetchBlockedPlaces();

  Future<void> blockPlace(String placeId);

  Future<void> unblockPlace(String placeId);
}
