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

  /// 저장한 코스 편집 (코스 상세 → 편집). 이 코스의 다시 추천 기준이 된다.
  void loadFromCourse(Course course) => state = CourseDraft.fromCourse(course);

  void update(CourseDraft Function(CourseDraft d) change) => state = change(state);
}

final courseDraftProvider = NotifierProvider<CourseDraftController, CourseDraft>(CourseDraftController.new);

/// 지역 묶음(홈 · 저장됨)에서 코스 만들기로 들어오면 3단계 장소 고르기를 그 지역(구)으로 걸러 연다.
/// 장소를 미리 고르지는 않는다 — 한 지역에 장소가 많아도 사용자가 3단계에서 고른다.
class PickerRegionController extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? region) => state = region;
}

final pickerRegionProvider = NotifierProvider<PickerRegionController, String?>(PickerRegionController.new);

/// 코스 만들기 진입점 (코스 탭 +, 첫 코스 만들기, 장소 상세, 보관함 상세)
void startCourseWizard(BuildContext context, WidgetRef ref, {List<Place> places = const [], String? region}) {
  ref.read(courseDraftProvider.notifier).start(places: places);
  ref.read(pickerRegionProvider.notifier).set(region);
  ref.invalidate(recommendationProvider);
  context.push(AppRoutes.courseNewInfo);
}
