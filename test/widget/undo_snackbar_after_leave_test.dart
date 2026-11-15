import 'package:apt/features/course/domain/course_models.dart';
import 'package:apt/features/course/presentation/recommendation_controller.dart';
import 'package:apt/features/course/presentation/widgets/course_edit_actions.dart';
import 'package:apt/features/place/domain/place.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Place _p(String id) => Place(id: id, name: id, address: '', categoryKey: 'cafe', categoryLabel: '카페');

final _a = CourseStop(place: _p('a'), source: PlaceSource.user);
final _b = CourseStop(place: _p('b'), source: PlaceSource.user);

/// 장소를 빼는 화면. 빼고 나면 스낵바에 '되돌리기'가 뜬다.
class _Editor extends ConsumerWidget {
  const _Editor();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      TextButton(onPressed: () => removeStopWithUndo(context, ref, _b), child: const Text('빼기'));
}

void main() {
  testWidgets('장소를 뺀 화면이 사라진 뒤에 되돌리기를 눌러도 오류 없이 되돌린다', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(recommendationProvider.notifier).startEditing(Course(id: 'c', title: '코스', stops: [_a, _b]));
    final showEditor = ValueNotifier(true);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder(
            valueListenable: showEditor,
            builder: (_, show, _) => show ? const _Editor() : const Text('코스 상세'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('빼기'));
    await tester.pumpAndSettle();
    expect(container.read(recommendationProvider).stops, hasLength(1));

    // 스낵바가 떠 있는 동안 화면이 바뀐다 (코스 저장 → 상세)
    showEditor.value = false;
    await tester.pump();
    expect(find.byType(_Editor), findsNothing);

    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(container.read(recommendationProvider).stops, hasLength(2));
  });
}
