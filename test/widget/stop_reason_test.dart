import 'package:apt/features/course/domain/course_models.dart';
import 'package:apt/features/course/presentation/widgets/course_stop_sheets.dart';
import 'package:apt/features/course/presentation/widgets/course_timeline.dart';
import 'package:apt/features/place/domain/place.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _reason = '저장 이력의 공원 관심과 같은 범주의 공원으로, 식사 뒤에 걷기 좋습니다.';
const _place = Place(id: 'p', name: '마포새빛문화숲', address: '서울 마포구 당인동', categoryKey: 'park', categoryLabel: '공원');
const _ai = CourseStop(place: _place, source: PlaceSource.ai, aiReason: _reason);
const _aiNoReason = CourseStop(place: _place, source: PlaceSource.ai);

Widget _sheetOpener(CourseStop stop) => MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showStopSheet(context, stop: stop, groups: [
              [StopSheetAction(label: '장소 정보 보기', icon: Icons.place_outlined, onTap: () {})],
            ]),
            child: const Text('열기'),
          ),
        ),
      ),
    );

void main() {
  testWidgets('일정의 AI 장소는 추천 이유 대신 종류 · 동네를 보여 준다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: CourseTimeline(stops: [_ai]))));

    expect(find.textContaining('공원 · 당인동'), findsOneWidget);
    expect(find.textContaining('저장 이력'), findsNothing);
    expect(find.textContaining('✦'), findsNothing);
  });

  testWidgets('일정의 동네는 번지 · 건물 번호가 아니라 동(없으면 구) 이름이다', (tester) async {
    Future<void> expectArea(String address, String shown) async {
      final stop = CourseStop(
        place: Place(id: address, name: '장소', address: address, categoryKey: 'c', categoryLabel: '공원'),
        source: PlaceSource.ai,
      );
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: CourseTimeline(stops: [stop]))));
      expect(find.textContaining(shown), findsOneWidget, reason: address);
    }

    await expectArea('서울 마포구 서교동 367-5', '공원 · 서교동');
    await expectArea('서울 마포구 토정로 56', '공원 · 마포구');
    await expectArea('서울 성동구 성수동1가 12', '공원 · 성수동1가');
    await expectArea('서울 성동구 성수동', '공원 · 성수동');
  });

  testWidgets("시트의 '추천 이유 보기'를 누르면 시트가 닫히지 않고 이유가 펼쳐진다", (tester) async {
    await tester.pumpWidget(_sheetOpener(_ai));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.text('추천 이유 보기'), findsOneWidget);
    expect(find.text(_reason), findsNothing);

    await tester.tap(find.text('추천 이유 보기'));
    await tester.pumpAndSettle();
    expect(find.text(_reason), findsOneWidget);
    expect(find.text('장소 정보 보기'), findsOneWidget); // 시트는 그대로 열려 있다

    await tester.tap(find.text('추천 이유 보기'));
    await tester.pumpAndSettle();
    expect(find.text(_reason), findsNothing);
  });

  testWidgets("추천 이유가 없으면 '추천 이유 보기' 줄이 없다", (tester) async {
    await tester.pumpWidget(_sheetOpener(_aiNoReason));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.text('장소 정보 보기'), findsOneWidget);
    expect(find.text('추천 이유 보기'), findsNothing);
  });
}
