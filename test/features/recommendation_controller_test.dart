import 'package:apt/app/di/repositories.dart';
import 'package:apt/core/error/app_failure.dart';
import 'package:apt/features/course/domain/course_draft.dart';
import 'package:apt/features/course/domain/course_models.dart';
import 'package:apt/features/course/domain/course_repository.dart';
import 'package:apt/features/course/presentation/course_draft_controller.dart';
import 'package:apt/features/course/presentation/recommendation_controller.dart';
import 'package:apt/features/place/domain/place.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Place _p(String id) => Place(id: id, name: id, address: '', categoryKey: 'cafe', categoryLabel: '카페');

/// 사용자 장소 뒤에 AI 장소 하나를 붙여 돌려주는 가짜 저장소
class _FakeCourseRepository implements CourseRepository {
  int calls = 0;
  bool fail = false;
  CourseDraft? lastDraft;

  @override
  Future<Recommendation> recommend({required CourseDraft draft, List<CourseStop> currentStops = const []}) async {
    calls++;
    lastDraft = draft;
    if (fail) throw const ServerFailure();
    return Recommendation(stops: [
      for (final p in draft.places) CourseStop(place: p, source: PlaceSource.user),
      CourseStop(place: _p('ai$calls'), source: PlaceSource.ai, aiReason: '이유'),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeCourseRepository repo;
  late ProviderContainer container;

  RecommendationController controller() => container.read(recommendationProvider.notifier);
  RecommendationState state() => container.read(recommendationProvider);
  CourseDraft draft() => container.read(courseDraftProvider);

  setUp(() {
    repo = _FakeCourseRepository();
    container = ProviderContainer(overrides: [courseRepositoryProvider.overrideWithValue(repo)], retry: (_, _) => null);
    container.read(courseDraftProvider.notifier).start(places: [_p('a'), _p('b')]);
  });

  tearDown(() => container.dispose());

  test('처음 진입하면 추천을 받고, 같은 장소로 다시 오면 다시 요청하지 않는다', () async {
    expect(await controller().syncWithDraft(), isFalse);
    expect(state().stops.map((s) => s.place.id), ['a', 'b', 'ai1']);
    await controller().syncWithDraft();
    expect(repo.calls, 1);
  });

  test('3/4에서 장소가 바뀌면 이전 결과를 무효화하고 새로 추천받는다', () async {
    await controller().syncWithDraft();
    container.read(courseDraftProvider.notifier).update((d) => d.addPlaces([_p('c')]));
    expect(await controller().syncWithDraft(), isTrue);
    expect(repo.calls, 2);
  });

  test('AI 추천을 빼면 제외 목록에 남고, 사용자 장소를 빼면 초안에서도 빠진다', () async {
    await controller().syncWithDraft();
    controller().removeStop(state().stops.last); // ai1
    expect(draft().rejectedPlaceIds, {'ai1'});
    controller().removeStop(state().stops.first); // a
    expect(draft().places.map((p) => p.id), ['b']);
    expect(state().stops.map((s) => s.place.id), ['b']);
  });

  test('다른 추천은 라운드를 올리고, 실패하면 이전 결과를 유지한다', () async {
    await controller().syncWithDraft();
    repo.fail = true;
    await controller().recommendAgain();
    expect(draft().recommendationRound, 1);
    expect(state().error, isA<ServerFailure>());
    expect(state().stops.map((s) => s.place.id), ['a', 'b', 'ai1']);
    expect(state().loading, isFalse);
  });

  test('순서를 바꾸면 사용자 장소 순서가 초안에 반영된다', () async {
    await controller().syncWithDraft();
    controller().moveStop(0, 2); // a를 b 뒤로
    expect(state().stops.map((s) => s.place.id), ['b', 'a', 'ai1']);
    expect(draft().places.map((p) => p.id), ['b', 'a']);
  });
}
