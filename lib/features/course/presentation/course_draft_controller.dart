import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../place/domain/place.dart';
import '../domain/course_draft.dart';
import '../domain/course_models.dart';
import 'recommendation_controller.dart';

/// 위저드 전 단계가 공유하는 CourseDraft. 뒤로 가도 입력이 유지된다.
class CourseDraftController extends Notifier<CourseDraft> {
  @override
  CourseDraft build() => const CourseDraft();

  /// 새 코스 시작. 장소 상세/보관함에서 들어오면 장소를 사전 선택한다.
  void start({List<Place> places = const []}) => state = CourseDraft(places: places);

  /// 완성된 코스로 루프 재진입 (코스 상세 → 다른 추천 받기 / 장소 추가)
  void loadFromCourse(Course course) => state = CourseDraft.fromCourse(course);

  void update(CourseDraft Function(CourseDraft d) change) => state = change(state);
}

final courseDraftProvider = NotifierProvider<CourseDraftController, CourseDraft>(CourseDraftController.new);

/// 코스 만들기 진입점 (코스 탭 +, 첫 코스 만들기, 장소 상세, 보관함 상세)
void startCourseWizard(BuildContext context, WidgetRef ref, {List<Place> places = const []}) {
  ref.read(courseDraftProvider.notifier).start(places: places);
  ref.invalidate(recommendationProvider);
  context.push(AppRoutes.courseNewInfo);
}

/// 완성된 코스에서 루프 재진입 (코스 상세 → 다른 추천 받기). 4/4 화면으로 바로 간다.
void reenterRecommendation(BuildContext context, WidgetRef ref, Course course) {
  ref.read(courseDraftProvider.notifier).loadFromCourse(course);
  ref.invalidate(recommendationProvider);
  context.push(AppRoutes.courseNewAi);
}
