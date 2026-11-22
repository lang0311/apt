// 임시 도구 (커밋 안 함): 흐름도 54개 화면을 에뮬레이터에서 차례로 열고 덤프한다.
// 실행: flutter test integration_test/_figma/scenes_mock.dart -d emulator-5554 --name "S[1-9]"  (README 참고)
import 'package:apt/app/routes.dart';
import 'package:apt/features/auth/domain/auth_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import '../helpers.dart';
import 'app_classes.dart';
import 'dump.dart';

late IntegrationTestWidgetsFlutterBinding binding;

GoRouter routerOf(WidgetTester t) => GoRouter.of(t.element(find.byType(Scaffold).first));

Future<void> shot(WidgetTester t, String name, {int settleSec = 3}) async {
  try {
    await settle(t, seconds: settleSec);
    await dumpScreen(t, binding, name, settleSec: 0);
  } catch (e, st) {
    debugPrint('SHOTFAIL $name: $e\n$st');
  }
}

/// 한 화면이 실패해도 같은 흐름의 다음 화면을 시도하지 못하므로, 실패 시 로그만 남기고 끝낸다.
Future<void> step(String name, Future<void> Function() body) async {
  try {
    await body();
  } catch (e) {
    debugPrint('STEPFAIL $name: ${e.toString().split('\n').first}');
  }
}

Future<void> scrollDown(WidgetTester t, {double dy = -700}) async {
  final all = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).evaluate().toList();
  if (all.isNotEmpty) {
    all.sort((a, b) => (b.renderObject as RenderBox).size.height.compareTo((a.renderObject as RenderBox).size.height));
    await t.drag(find.byElementPredicate((e) => e == all.first), Offset(0, dy), warnIfMissed: false);
  }
  await t.pump(const Duration(milliseconds: 600));
}

void main() {
  binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => appClasses = appClassNames);

  testWidgets('S1a 로그인 · 신규 가입', (tester) async {
    await prepareCapture(binding, tester);
    await launchApp(tester);
    await shot(tester, 'a01_login');
    routerOf(tester).push(AppRoutes.loginError, extra: '카카오 로그인에 실패했어요.');
    await tester.pump(const Duration(milliseconds: 600));
    await shot(tester, 'a02_login_error');
    routerOf(tester).pop();
    await tester.pump(const Duration(milliseconds: 600));
    await step('a03', () async {
      await tapFinder(tester, find.byTooltip('카카오로 로그인'), scroll: false);
      await waitFor(tester, find.text('서비스 이용에 동의해 주세요'));
      await shot(tester, 'a03_terms');
      await tapText(tester, '전체 동의');
      await shot(tester, 'a04_terms_checked');
      await tapFinder(tester, find.widgetWithText(InkWell, '동의하고 계속하기'));
      await waitFor(tester, find.text('어떻게 불러\n드릴까요?'));
      await shot(tester, 'a05_profile');
      await tapText(tester, '가입 완료');
      await waitFor(tester, find.textContaining('가입이 끝났어요'));
      await shot(tester, 'a06_signup_done');
    });
  });

  testWidgets('S1b 아이디 가입', (tester) async {
    await prepareCapture(binding, tester);
    await launchApp(tester);
    await step('a07', () async {
      await tapText(tester, '회원가입');
      await waitFor(tester, find.text('서비스 이용에 동의해 주세요'));
      await tapText(tester, '전체 동의');
      await tapFinder(tester, find.widgetWithText(InkWell, '동의하고 계속하기'));
      await waitFor(tester, find.text('계정을 만들어 주세요'));
      final fields = find.byType(TextField);
      await typeInto(tester, fields.at(0), 'taken');
      await typeInto(tester, fields.at(1), 'password1');
      await typeInto(tester, fields.at(2), '여행하는 지상');
      await tapText(tester, '가입하기');
      await waitFor(tester, find.text('이미 사용 중인 아이디예요.'));
      await shot(tester, 'a07_id_signup');
    });
  });

  testWidgets('S1c 계정 충돌 · 로그인 실패', (tester) async {
    await prepareCapture(binding, tester);
    await launchApp(tester);
    await step('a09', () async {
      final fields = find.byType(TextField);
      await typeInto(tester, fields.at(0), 'demo_user1');
      await typeInto(tester, fields.at(1), 'wrongpass');
      await tapText(tester, '로그인');
      await waitFor(tester, find.text('아이디 또는 비밀번호가 맞지 않아요.'));
      await shot(tester, 'a09_login_failed');
    });
    await step('a08', () async {
      routerOf(tester).push(
        AppRoutes.loginConflict,
        extra: const AccountConflict(maskedEmail: 'jis***@gmail.com', existingMethodLabel: '이메일로 가입한 계정', provider: SocialProvider.google),
      );
      await waitFor(tester, find.text('이미 가입된 이메일이에요'));
      await shot(tester, 'a08_account_conflict');
    });
  });

  testWidgets('S2 홈', (tester) async {
    await prepareCapture(binding, tester);
    await signInExisting(tester);
    await shot(tester, 'b01_home');
    await scrollDown(tester, dy: -900);
    await shot(tester, 'b02_home_bottom', settleSec: 2);
  });

  testWidgets('S3 저장됨 · 장소 상세', (tester) async {
    await prepareCapture(binding, tester);
    await signInExisting(tester);
    await tapTab(tester, '저장됨');
    await waitFor(tester, find.text('보관함'));
    await tester.pump(const Duration(seconds: 2));
    await shot(tester, 'c01_saved_places');
    await step('c02', () async {
      await tapText(tester, '지역별', scroll: false);
      await tapText(tester, '업종별', scroll: false);
      await tapText(tester, '필터', scroll: false);
      await shot(tester, 'c02_filter_sheet', settleSec: 1);
      await tapFinder(tester, find.text('맛집').last, scroll: false);
      await tapFinder(tester, find.textContaining('곳 보기'), scroll: false);
      await waitFor(tester, find.bySemanticsLabel('맛집 필터 해제'));
      await shot(tester, 'c03_saved_filtered');
      await tapText(tester, '연남식당');
      await waitFor(tester, find.text('장소 정보'));
      await shot(tester, 'c04_place_detail');
      await scrollDown(tester, dy: -900);
      await shot(tester, 'c05_place_detail_bottom', settleSec: 1);
      await scrollDown(tester, dy: 900);
      await tapText(tester, '변경');
      await waitFor(tester, find.text('보관함 변경하기'));
      await shot(tester, 'c06_collection_change_sheet', settleSec: 1);
    });
  });

  testWidgets('S4 보관함 · 저장 지도', (tester) async {
    await prepareCapture(binding, tester);
    await signInExisting(tester);
    await tapTab(tester, '저장됨');
    await tapText(tester, '보관함', scroll: false);
    await tester.pump(const Duration(milliseconds: 600));
    await shot(tester, 'c07_collections');
    await step('c08', () async {
      await tapText(tester, '조용한 카페');
      await tester.pump(const Duration(milliseconds: 800));
      await shot(tester, 'c08_collection_detail');
      routerOf(tester).pop();
      await tester.pump(const Duration(milliseconds: 600));
    });
    await step('c09', () async {
      await tapText(tester, '새 보관함');
      await waitFor(tester, find.text('보관함 이름'));
      await shot(tester, 'c09_new_collection', settleSec: 1);
      await typeInto(tester, find.byType(TextField).last, '서울 가을 산책');
      await tapText(tester, '보관함 만들기');
      await waitFor(tester, find.text('아직 담은 장소가 없어요'));
      await shot(tester, 'c10_collection_empty');
    });
    await step('c11', () async {
      routerOf(tester).go(AppRoutes.categoryMap());
      await tester.pump(const Duration(seconds: 1));
      await shot(tester, 'c11_saved_map', settleSec: 5);
    });
  });

  testWidgets('S5 추출 · 장소 찾기', (tester) async {
    await prepareCapture(binding, tester);
    await signInExisting(tester);
    await tapTab(tester, '장소 추가');
    await waitFor(tester, find.text('릴스에서 바로 저장하는 게 가장 빨라요'));
    await shot(tester, 'd01_extract');
    await step('d02', () async {
      await typeInto(tester, find.byType(TextField).first, 'https://www.instagram.com/reel/DA7mNpQrStU/');
      await tapText(tester, '찾기');
      await shot(tester, 'd02_extract_searching', settleSec: 0);
      await waitFor(tester, find.text('2곳을 찾았어요'));
      await shot(tester, 'd03_extract_result');
      await tapText(tester, '보관함 고르기 ›');
      await waitFor(tester, find.text('새 보관함'));
      await shot(tester, 'd04_collection_select', settleSec: 1);
      await tapText(tester, '확인');
      await tapText(tester, '1곳 저장');
      await waitFor(tester, find.text('1곳을 저장했어요'));
      await shot(tester, 'd05_extract_saved', settleSec: 1);
    });
  });

  testWidgets('S5b 비공개 · 지도 검색', (tester) async {
    await prepareCapture(binding, tester);
    await signInExisting(tester);
    await tapTab(tester, '장소 추가');
    await step('d06', () async {
      await typeInto(tester, find.byType(TextField).first, 'https://www.instagram.com/p/private123/');
      await tapText(tester, '찾기');
      await waitFor(tester, find.text('비공개 게시물이에요'));
      await shot(tester, 'd06_extract_private');
      await tapText(tester, '다른 링크 넣기');
    });
    await step('d07', () async {
      await tapText(tester, '지도에서 찾기');
      await tester.pump(const Duration(seconds: 1));
      await shot(tester, 'd07_place_search', settleSec: 5);
    });
  });

  testWidgets('S6 코스 만들기', (tester) async {
    await prepareCapture(binding, tester);
    await signInExisting(tester);
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
      await typeInto(tester, find.byType(TextField).first, '가을 서울 카페 산책');
      await tapText(tester, '내일');
      await shot(tester, 'e04_info_filled', settleSec: 1);
      await tapText(tester, '다음');
      await waitFor(tester, find.text('누구와 함께 가나요?'));
      await shot(tester, 'e05_companion_solo', settleSec: 1);
      await tapText(tester, '함께 가요');
      await waitFor(tester, find.text('어느 파티와 갈까요?'));
      await tapText(tester, '새 파티 만들기');
      await waitFor(tester, find.text('파티원 1'));
      await shot(tester, 'e06_companion_new_party', settleSec: 1);
      await tapText(tester, '초대하기');
      await waitFor(tester, find.text('파티원 초대'));
      await shot(tester, 'e07_invite_sheet', settleSec: 1);
      await tester.tapAt(const Offset(20, 120));
      await tester.pump(const Duration(milliseconds: 600));
      await tapText(tester, '나, 민지, 랑이');
      await shot(tester, 'e08_companion_party', settleSec: 1);
      await tapText(tester, '다음');
    });
    await step('e09', () async {
      await tester.pump(const Duration(seconds: 1));
      await shot(tester, 'e09_places_map', settleSec: 5);
      await tapFinder(tester, find.textContaining('목록 '), scroll: false);
      await tapText(tester, '카페 온더뷰');
      await tapText(tester, '연남식당');
      await waitFor(tester, find.text('고른 곳 2'));
      await shot(tester, 'e10_places_list', settleSec: 2);
      await tapText(tester, '2곳으로 코스 추천받기', scroll: false);
      await waitFor(tester, find.text('후보 장소 찾기'));
      await shot(tester, 'e11_ai_waiting', settleSec: 0);
      await waitFor(tester, find.text('코스 저장'), timeout: const Duration(seconds: 25));
      await shot(tester, 'e12_ai_result');
      await scrollDown(tester, dy: -900);
      await shot(tester, 'e13_ai_result_bottom', settleSec: 1);
      await scrollDown(tester, dy: 900);
      await tapText(tester, '코스 저장', scroll: false);
      await waitFor(tester, find.text('코스가 저장되었어요'));
      await waitFor(tester, find.text('민지, 랑이에게 알릴까요?'));
      await shot(tester, 'e14_notify_sheet', settleSec: 2);
      await tapText(tester, '나중에', scroll: false);
      await waitGone(tester, find.text('민지, 랑이에게 알릴까요?'));
      await shot(tester, 'e15_course_detail');
    });
  });

  testWidgets('S7 코스 상세 · 편집', (tester) async {
    await prepareCapture(binding, tester);
    await signInExisting(tester);
    await tapTab(tester, '코스');
    await tapText(tester, '서울 카페 투어');
    await waitFor(tester, find.textContaining(RegExp(r'^일정 \d+곳$')));
    await shot(tester, 'e16_course_detail_saved');
    await step('e17', () async {
      await tapText(tester, '편집');
      await waitFor(tester, find.text('코스 편집'));
      await shot(tester, 'e17_course_edit');
      final removeButtons = find.byWidgetPredicate((w) => w is IconButton && (w.tooltip?.endsWith(' 빼기') ?? false));
      await tapFinder(tester, removeButtons, scroll: false);
      await waitFor(tester, find.textContaining('이번 코스에서 뺐어요'));
      await shot(tester, 'e18_course_edit_removed', settleSec: 1);
    });
    await step('e19', () async {
      routerOf(tester).go(AppRoutes.coursesParty);
      await tester.pump(const Duration(seconds: 1));
      await shot(tester, 'e19_courses_party');
    });
  });

  testWidgets('S8 초대', (tester) async {
    await prepareCapture(binding, tester);
    await signInExisting(tester);
    await step('f01', () async {
      routerOf(tester).go('/invites/demo');
      await waitFor(tester, find.text('민지님이 코스에\n초대했어요'));
      await shot(tester, 'f01_invite_accept');
    });
    await step('f02', () async {
      routerOf(tester).go('/invites/expired');
      await waitFor(tester, find.text('초대가 만료됐어요'));
      await shot(tester, 'f02_invite_expired', settleSec: 1);
    });
  });

  testWidgets('S9 마이', (tester) async {
    await prepareCapture(binding, tester);
    await signInExisting(tester);
    await tapTab(tester, '마이');
    await waitFor(tester, find.text('저장한 곳'));
    await shot(tester, 'g01_my');
    await step('g02', () async {
      await tapText(tester, '보기');
      await waitFor(tester, find.textContaining('저장한 장소로 취향을 읽어요'));
      await shot(tester, 'g02_preferences');
      routerOf(tester).pop();
      await tester.pump(const Duration(milliseconds: 600));
      await tapText(tester, '추천하지 않는 장소');
      await tester.pump(const Duration(seconds: 1));
      await shot(tester, 'g03_blocked_places');
      routerOf(tester).pop();
      await tester.pump(const Duration(milliseconds: 600));
      await tapText(tester, '로그아웃');
      await waitFor(tester, find.text('로그아웃할까요?'));
      await shot(tester, 'g04_logout_confirm', settleSec: 1);
    });
  });
}
