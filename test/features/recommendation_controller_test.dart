import 'dart:async';

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

  /// 설정하면 이 Future가 끝날 때까지 응답을 미룬다 (진행 중 상태 확인용)
  Future<void>? gate;
  List<RecommendationStage> stages = const [];
  int cancels = 0;

  @override
  Future<Recommendation> recommend({
    required CourseDraft draft,
    List<CourseStop> currentStops = const [],
    void Function(RecommendationStage stage)? onStage,
  }) async {
    calls++;
    lastDraft = draft;
    stages.forEach(onStage ?? (_) {});
    if (gate != null) await gate;
    if (fail) throw const ServerFailure();
    return Recommendation(stops: [
      for (final p in draft.places) CourseStop(place: p, source: PlaceSource.user),
      CourseStop(place: _p('ai$calls'), source: PlaceSource.ai, aiReason: '이유'),
    ]);
  }

  @override
  Future<void> cancelRecommendation() async => cancels++;
  @override
  Future<String> courseLink(String courseId) async => throw UnimplementedError();

  final blocked = <String>{};

  @override
  Future<void> blockPlace(String placeId) async => blocked.add(placeId);

  @override
  Future<void> unblockPlace(String placeId) async => blocked.remove(placeId);

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

  test('앞으로 추천하지 않기는 계정 차단 + 이 코스에서 빼기, 되돌리면 둘 다 되돌린다', () async {
    await controller().syncWithDraft();
    final ai = state().stops.last;
    await controller().blockStop(ai);
    expect(repo.blocked, {'ai1'});
    expect(state().stops.map((s) => s.place.id), ['a', 'b']);
    await controller().undo();
    expect(repo.blocked, isEmpty);
    expect(state().stops.map((s) => s.place.id), ['a', 'b', 'ai1']);
    expect(draft().rejectedPlaceIds, isEmpty);
  });

  test('다시 추천은 바뀐 AI 장소를 알려 주고, 되돌리면 직전 결과로 돌아간다', () async {
    await controller().syncWithDraft();
    final n = await controller().recommendAgain();
    expect(n, 1);
    expect(state().changedIds, {'ai2'});
    await controller().undo();
    expect(state().stops.map((s) => s.place.id), ['a', 'b', 'ai1']);
    expect(state().changedIds, isEmpty);
  });

  test('저장한 코스 편집: 시작 값과 달라지면 isDirty', () {
    final course = Course(id: 'k1', title: '코스', stops: [
      CourseStop(place: _p('a'), source: PlaceSource.user),
      CourseStop(place: _p('x'), source: PlaceSource.ai),
    ]);
    controller().startEditing(course);
    expect(controller().isDirty, isFalse);
    expect(draft().name, '코스');
    controller().removeStop(state().stops.last);
    expect(controller().isDirty, isTrue);
    expect(draft().rejectedPlaceIds, {'x'});
  });

  test('진행 단계는 앞으로만 간다 (서버 단계가 되돌아가도)', () async {
    final gate = Completer<void>();
    repo
      ..gate = gate.future
      ..stages = [RecommendationStage.checkPlaces, RecommendationStage.findCandidates];
    final done = controller().syncWithDraft();
    await Future<void>.delayed(Duration.zero);
    expect(state().loading, isTrue);
    expect(state().stage, RecommendationStage.checkPlaces);
    gate.complete();
    await done;
    expect(state().stage, isNull);
  });

  test('처음 추천을 취소하면 결과 없이 바로 돌아가고, 늦게 온 응답은 버린다', () async {
    final gate = Completer<void>();
    repo.gate = gate.future;
    final done = controller().syncWithDraft();
    await Future<void>.delayed(Duration.zero);
    expect(controller().cancel(), isTrue);
    expect(state().loading, isFalse);
    expect(state().hasResult, isFalse);
    expect(state().error, isNull);
    await Future<void>.delayed(Duration.zero);
    expect(repo.cancels, 1);
    gate.complete();
    await done;
    expect(state().hasResult, isFalse);
    expect(state().loading, isFalse);
  });

  test('다시 추천을 취소하면 이전 결과와 라운드로 돌아가고 되돌리기는 남지 않는다', () async {
    await controller().syncWithDraft();
    final gate = Completer<void>();
    repo.gate = gate.future;
    final again = controller().recommendAgain();
    await Future<void>.delayed(Duration.zero);
    expect(draft().recommendationRound, 1);
    controller().cancel();
    expect(state().stops.map((s) => s.place.id), ['a', 'b', 'ai1']);
    expect(draft().recommendationRound, 0);
    expect(controller().canUndo, isFalse);
    gate.complete();
    expect(await again, isNull);
    expect(state().stops.map((s) => s.place.id), ['a', 'b', 'ai1']);
  });

  test('바꾸기를 취소하면 뺀 AI 장소도 돌아온다', () async {
    await controller().syncWithDraft();
    final gate = Completer<void>();
    repo.gate = gate.future;
    final replace = controller().replaceAi(state().stops.last);
    await Future<void>.delayed(Duration.zero);
    controller().cancel();
    expect(state().stops.map((s) => s.place.id), ['a', 'b', 'ai1']);
    expect(draft().rejectedPlaceIds, isEmpty);
    gate.complete();
    await replace;
    expect(state().stops.map((s) => s.place.id), ['a', 'b', 'ai1']);
  });

  test('진행 중이 아니면 취소는 아무것도 하지 않는다', () async {
    await controller().syncWithDraft();
    expect(controller().cancel(), isFalse);
    expect(repo.cancels, 0);
  });
}
