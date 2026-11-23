import 'package:apt/features/course/domain/course_models.dart';
import 'package:apt/features/course/presentation/widgets/course_stop_sheets.dart';
import 'package:apt/features/place/domain/place.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _place = Place(id: 'p', name: '대림창고', address: '서울 성동구 성수이로 78', categoryKey: 'culture', categoryLabel: '갤러리');

Widget _opener(CourseStop stop) => MaterialApp(
  home: Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () => showResultStopSheet(context, stop: stop, onInfo: () {}, onRemove: () {}),
        child: const Text('열기'),
      ),
    ),
  ),
);

/// 2번 B안: 장소 시트의 '추천에 쓴 글 n개' → 다음 시트, ‹ 뒤로 = 장소 시트
void main() {
  testWidgets('추천에 쓴 글이 있으면 줄이 생기고, 누르면 글 목록 시트, 뒤로 가면 장소 시트', (tester) async {
    final stop = CourseStop(
      place: _place,
      source: PlaceSource.ai,
      aiReason: '전시가 열려요',
      evidence: [
        PlaceEvidence(url: 'https://www.korean.visitseoul.net/a', quote: '1970년대 창고를 고친 갤러리', publishedAt: DateTime(2026, 11, 2)),
        const PlaceEvidence(url: 'https://blog.naver.com/b', quote: '평일 낮엔 한산해요'),
      ],
    );
    await tester.pumpWidget(_opener(stop));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('추천에 쓴 글 2개'));
    await tester.pumpAndSettle();

    expect(find.text('대림창고 · 추천에 쓴 글'), findsOneWidget);
    expect(find.text('korean.visitseoul.net · 2026년 11월 2일'), findsOneWidget);
    expect(find.text('blog.naver.com'), findsOneWidget);
    expect(find.text('평일 낮엔 한산해요'), findsOneWidget);

    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    expect(find.text('추천에 쓴 글 2개'), findsOneWidget);
    expect(find.text('대림창고 · 추천에 쓴 글'), findsNothing);
  });

  testWidgets('글이 없으면 줄이 없다', (tester) async {
    await tester.pumpWidget(_opener(const CourseStop(place: _place, source: PlaceSource.ai)));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('추천에 쓴 글'), findsNothing);
  });
}
