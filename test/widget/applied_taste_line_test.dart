import 'package:apt/app/theme/app_theme.dart';
import 'package:apt/features/course/domain/course_models.dart';
import 'package:apt/features/course/presentation/widgets/course_timeline.dart';
import 'package:apt/features/party/domain/party_models.dart';
import 'package:apt/features/place/domain/place.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// 일정 카드의 반영한 취향 한 줄 (07 D46)
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pumpLine(WidgetTester tester, AppliedTaste taste, {double width = 390}) async {
    tester.view.physicalSize = Size(width, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: AppliedTasteLine(taste: taste)),
    ));
  }

  testWidgets('혼자 코스: "단어 · 단어 취향을 반영했어요"', (tester) async {
    await pumpLine(tester, const AppliedTaste(words: ['자연', '미식']));
    expect(find.text('자연 · 미식 취향을 반영했어요', findRichText: true), findsOneWidget);
    expect(find.bySemanticsLabel('자연 · 미식 취향을 반영했어요'), findsOneWidget);
  });

  testWidgets('파티 코스: "파티원 n명의 …"', (tester) async {
    await pumpLine(tester, const AppliedTaste(words: ['미식', '카페'], memberCount: 3));
    expect(find.text('파티원 3명의 미식 · 카페 취향을 반영했어요', findRichText: true), findsOneWidget);
  });

  testWidgets('파티 코스에 공유한 단어가 없으면 인원만', (tester) async {
    await pumpLine(tester, const AppliedTaste(words: [], memberCount: 3));
    expect(find.text('파티원 3명의 취향을 반영했어요', findRichText: true), findsOneWidget);
    expect(find.bySemanticsLabel('파티원 3명의 취향을 반영했어요'), findsOneWidget);
  });

  testWidgets('좁은 화면에서 단어가 많아도 한 줄로 말줄임 (overflow 없음)', (tester) async {
    await pumpLine(tester, const AppliedTaste(words: ['미식', '자연', '카페', '한식', '디저트카페'], memberCount: 8), width: 320);
    expect(tester.takeException(), isNull);
  });

  group('파티 코스 펼치기', () {
    const members = [
      PartyMember(id: 'test', nickname: 'lang', isMe: true),
      PartyMember(id: 'jimin', nickname: '지민'),
      PartyMember(id: 'youngseo', nickname: '영서'),
    ];
    CourseStop stop(String id, String name) =>
        CourseStop(place: Place(id: id, name: name, address: '서울 마포구 연남동', categoryKey: 'cafe', categoryLabel: '카페'), source: PlaceSource.ai);
    final stops = [
      stop('k-forest', '경의선숲길'),
      stop('k-cafe', '카페공명 연남점'),
      stop('k-hansik', '진청유점'),
      stop('k-bar', '잊힐리야 연남'),
    ];
    const taste = AppliedTaste(
      words: ['미식'],
      memberCount: 3,
      matches: {
        'k-cafe': ['jimin', 'youngseo'],
        'k-hansik': ['test'],
        'k-bar': ['jimin'],
        'gone': ['jimin'], // 편집으로 빠진 장소
      },
    );

    Future<void> pump(WidgetTester tester, AppliedTaste t, {List<PartyMember>? m = members, double width = 390}) async {
      tester.view.physicalSize = Size(width, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: AppliedTasteLine(taste: t, stops: stops, members: m)),
      ));
    }

    testWidgets('링크를 누르면 시트에 일정 순서대로 장소와 이름이 나온다 (07 D57)', (tester) async {
      await pump(tester, taste);
      expect(find.text('누구 취향인지 보기'), findsOneWidget);
      expect(find.text('카페공명 연남점'), findsNothing);

      await tester.tap(find.text('누구 취향인지 보기'));
      await tester.pumpAndSettle();
      final names = ['카페공명 연남점', '진청유점', '잊힐리야 연남'];
      final ys = [for (final n in names) tester.getTopLeft(find.text(n)).dy];
      expect(ys, orderedEquals([...ys]..sort()));
      expect(find.text('경의선숲길'), findsNothing); // 맞는 사람이 없는 곳은 뺌
      expect(find.text('나'), findsOneWidget);
      expect(find.text('지민'), findsNWidgets(2));
      expect(find.text('영서'), findsOneWidget);

      expect(find.text('장소마다 누구 취향인지'), findsOneWidget); // 시트 제목
      await tester.tapAt(const Offset(10, 10)); // 시트 바깥을 눌러 닫는다
      await tester.pumpAndSettle();
      expect(find.text('카페공명 연남점'), findsNothing);
    });

    testWidgets('파티원 모두에게 맞으면 "모두", 반영되지 못한 파티원은 맨 아래 한 줄', (tester) async {
      await pump(
        tester,
        const AppliedTaste(
          words: [],
          memberCount: 3,
          matches: {'k-cafe': ['test', 'jimin', 'youngseo']},
          gaps: [TasteGap(memberId: 'youngseo', noHistory: true), TasteGap(memberId: 'jimin', noHistory: false)],
        ),
      );
      await tester.tap(find.text('누구 취향인지 보기'));
      await tester.pumpAndSettle();
      expect(find.text('모두'), findsOneWidget);
      expect(find.text('영서는 저장한 장소가 없어 반영하지 못했어요'), findsOneWidget);
      expect(find.text('지민 취향에 잘 맞는 장소는 찾지 못했어요'), findsOneWidget);
    });

    testWidgets('파티원을 아직 모르면 링크 없이 한 줄만', (tester) async {
      await pump(tester, taste, m: null);
      expect(find.text('누구 취향인지 보기'), findsNothing);
      expect(find.text('파티원 3명의 미식 취향을 반영했어요', findRichText: true), findsOneWidget);
    });

    testWidgets('좁은 화면에서 시트를 열어도 넘치지 않는다', (tester) async {
      await pump(tester, taste, width: 320);
      await tester.tap(find.text('누구 취향인지 보기'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
