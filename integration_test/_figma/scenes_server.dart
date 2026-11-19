// 피그마 흐름도용: 서버 모드(APT_BACKEND=true)로 화면을 뽑는다. 계정은 읽기만 하고, 코스는 저장하지 않는다.
// 계정은 코드에 두지 않는다: --dart-define=FIGMA_USER=... --dart-define=FIGMA_PW=... (README 참고)
import 'package:apt/app/app.dart';
import 'package:apt/app/routes.dart';
import 'package:apt/features/home/presentation/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../helpers.dart';
import 'app_classes.dart';
import 'dump.dart';
import 'scenes_mock.dart' as sc;

const _user = String.fromEnvironment('FIGMA_USER');
const _pw = String.fromEnvironment('FIGMA_PW');

Future<void> loginTest(WidgetTester tester) async {
  if (_user.isEmpty || _pw.isEmpty) throw StateError('--dart-define=FIGMA_USER, FIGMA_PW가 필요해요');
  await tester.pumpWidget(const AptRoot());
  final end = DateTime.now().add(const Duration(seconds: 20));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (find.byTooltip('Google로 로그인').evaluate().isNotEmpty || find.byType(HomePage).evaluate().isNotEmpty) break;
  }
  if (find.byType(HomePage).evaluate().isNotEmpty) {
    await settle(tester, seconds: 3);
    return;
  }
  final fields = find.byType(TextField);
  await typeInto(tester, fields.at(0), _user);
  await typeInto(tester, fields.at(1), _pw);
  await tapText(tester, '로그인');
  await waitFor(tester, find.byType(HomePage), timeout: const Duration(seconds: 30));
  await settle(tester, seconds: 3);
}

void main() {
  sc.binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final shot = sc.shot;
  final step = sc.step;

  setUpAll(() => appClasses = appClassNames);

  testWidgets('V1 로그인 실패 · 아이디 가입 오류', (tester) async {
    await prepareCapture(sc.binding, tester);
    await launchApp(tester);
    await step('a09', () async {
      final fields = find.byType(TextField);
      await typeInto(tester, fields.at(0), _user);
      await typeInto(tester, fields.at(1), 'wrongpass');
      await tapText(tester, '로그인');
      await settle(tester, seconds: 4);
      await shot(tester, 'a09_login_failed');
    });
    await step('a07', () async {
      await tapText(tester, '회원가입');
      await waitFor(tester, find.text('약관 동의'));
      await tapText(tester, '전체 동의');
      await tapFinder(tester, find.widgetWithText(InkWell, '동의하고 계속하기'));
      await waitFor(tester, find.text('로그인에 쓸 아이디와 비밀번호를 정해주세요.'));
      final fields = find.byType(TextField);
      await typeInto(tester, fields.at(0), _user); // 이미 있는 아이디 → 서버가 거절 (계정은 만들어지지 않는다)
      await typeInto(tester, fields.at(1), 'password1');
      await typeInto(tester, fields.at(2), '여행하는 지상');
      await tapText(tester, '가입하기');
      await settle(tester, seconds: 4);
      await shot(tester, 'a07_id_signup');
    });
  });

  testWidgets('V2 홈 · 저장됨 · 장소 상세 · 저장 지도', (tester) async {
    await prepareCapture(sc.binding, tester);
    await loginTest(tester);
    await shot(tester, 'b01_home');
    await sc.scrollDown(tester, dy: -900);
    await shot(tester, 'b02_home_bottom', settleSec: 2);
    await tapTab(tester, '저장됨');
    await waitFor(tester, find.textContaining('전체 '));
    await shot(tester, 'c01_saved_places');
    await step('c02', () async {
      await tapText(tester, '지역별', scroll: false);
      await tapText(tester, '업종별', scroll: false);
      await tapText(tester, '필터', scroll: false);
      await shot(tester, 'c02_filter_sheet', settleSec: 1);
      await tapFinder(tester, find.text('한식').last, scroll: false);
      await tapFinder(tester, find.textContaining('곳 보기'), scroll: false);
      await tester.pump(const Duration(seconds: 1));
      await shot(tester, 'c03_saved_filtered');
      await tapText(tester, '필운동주');
      await waitFor(tester, find.text('장소 정보'));
      await shot(tester, 'c04_place_detail');
      await sc.scrollDown(tester, dy: -900);
      await shot(tester, 'c05_place_detail_bottom', settleSec: 1);
    });
    await step('c11', () async {
      sc.routerOf(tester).go(AppRoutes.categoryMap());
      await tester.pump(const Duration(seconds: 1));
      await shot(tester, 'c11_saved_map', settleSec: 5);
    });
  });

  testWidgets('V3 장소 추가 · 지도 검색', (tester) async {
    await prepareCapture(sc.binding, tester);
    await loginTest(tester);
    await tapTab(tester, '장소 추가');
    await waitFor(tester, find.text('릴스에서 바로 저장하기'));
    await shot(tester, 'd01_extract');
    await step('d07', () async {
      await tapText(tester, '지도에서 검색하기');
      await tester.pump(const Duration(seconds: 1));
      await shot(tester, 'd07_place_search', settleSec: 5);
    });
  });

  testWidgets('V4 코스 만들기 (저장 안 함)', (tester) async {
    await prepareCapture(sc.binding, tester);
    await loginTest(tester);
    await tapTab(tester, '코스');
    await waitFor(tester, find.textContaining('내 코스', findRichText: true));
    await shot(tester, 'e01_courses');
    await step('e02', () async {
      await tapFinder(tester, find.byTooltip('코스 만들기'));
      await waitFor(tester, find.text('어떤 코스를 만들까요?'));
      await shot(tester, 'e02_info_empty', settleSec: 1);
      await tapText(tester, '출발 시간을 골라 주세요');
      await tester.pump(const Duration(seconds: 1));
      await shot(tester, 'e03_when_sheet', settleSec: 1);
      await tester.tapAt(const Offset(20, 80));
      await tester.pump(const Duration(milliseconds: 600));
    });
    await step('e04', () async {
      await typeInto(tester, find.byType(TextField).first, '가을 성수 카페 산책');
      await tapText(tester, '내일');
      await shot(tester, 'e04_info_filled', settleSec: 1);
      await tapText(tester, '다음');
      await waitFor(tester, find.text('누구와 함께 가나요?'));
      await shot(tester, 'e05_companion_solo', settleSec: 1);
      await tapText(tester, '함께 가요');
      await waitFor(tester, find.text('어느 파티와 갈까요?'));
      await tester.pump(const Duration(seconds: 1));
      await tapText(tester, '새 파티 만들기');
      await waitFor(tester, find.text('파티원 1'));
      await shot(tester, 'e06_companion_new_party', settleSec: 1);
      // 기존 파티 고르기 (서버가 준 첫 파티)
      await tapFinder(tester, find.textContaining('나, ').first, scroll: false);
      await shot(tester, 'e08_companion_party', settleSec: 1);
      await tapText(tester, '다음');
    });
    await step('e09', () async {
      await tester.pump(const Duration(seconds: 1));
      await shot(tester, 'e09_places_map', settleSec: 5);
      await tapFinder(tester, find.textContaining('목록 '), scroll: false);
      await tapText(tester, '더숲초소책방');
      await tapText(tester, '파란만잔 여의도점');
      await waitFor(tester, find.text('고른 곳 2'));
      await shot(tester, 'e10_places_list', settleSec: 2);
      // 실제 AI 추천 호출(비용)은 하지 않는다 → 4/4 화면(e11~e15)은 Mock으로 보충한다
      // 저장하지 않고 나간다
    });
  });

  testWidgets('V5 코스 상세 · 파티 코스 · 마이', (tester) async {
    await prepareCapture(sc.binding, tester);
    await loginTest(tester);
    await tapTab(tester, '코스');
    await step('e16', () async {
      await tapText(tester, 'seongsu 7');
      await waitFor(tester, find.textContaining(RegExp(r'^일정 \d+곳$')));
      await shot(tester, 'e16_course_detail_saved');
    });
    await step('e19', () async {
      sc.routerOf(tester).go(AppRoutes.coursesParty);
      await tester.pump(const Duration(seconds: 1));
      await shot(tester, 'e19_courses_party');
    });
    await step('g01', () async {
      await tapTab(tester, '마이');
      await waitFor(tester, find.text('저장한 곳'));
      await shot(tester, 'g01_my');
      await tapText(tester, find.text('수정').evaluate().isNotEmpty ? '수정' : '보기'); // 서버 모드는 '보기'
    });
    await step('g02', () async {
      await tester.pump(const Duration(seconds: 1));
      await shot(tester, 'g02_preferences');
      sc.routerOf(tester).pop();
      await tester.pump(const Duration(milliseconds: 600));
      await tapText(tester, '추천하지 않는 장소');
      await tester.pump(const Duration(seconds: 1));
      await shot(tester, 'g03_blocked_places');
      sc.routerOf(tester).pop();
      await tester.pump(const Duration(milliseconds: 600));
      await tapText(tester, '로그아웃');
      await waitFor(tester, find.text('로그아웃할까요?'));
      await shot(tester, 'g04_logout_confirm', settleSec: 1);
    });
  });
}
