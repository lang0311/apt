import 'package:apt/app/app.dart';
import 'package:apt/app/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 로딩 인디케이터가 계속 도는 화면에서도 쓸 수 있게 pumpAndSettle 대신 조건 대기.
Future<void> waitFor(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 15)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('시간 안에 찾지 못함: $finder');
}

Future<void> waitGone(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 15)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isEmpty) return;
  }
  throw TestFailure('시간 안에 사라지지 않음: $finder');
}

/// 지연 생성 목록(ListView)에서 화면 밖이라 아직 만들어지지 않은 항목은 스크롤하며 찾는다.
Future<void> findOrScroll(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 15)}) async {
  final end = DateTime.now().add(timeout);
  var scrolls = 0;
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
    // 1초 기다려도 없으면 가장 바깥 세로 스크롤을 내린다 (최대 12번)
    final waited = timeout - end.difference(DateTime.now());
    if (waited > Duration(seconds: 1 + scrolls) && scrolls < 12) {
      final scrollables = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);
      if (scrollables.evaluate().isNotEmpty) {
        await tester.drag(scrollables.first, const Offset(0, -250), warnIfMissed: false);
      }
      scrolls++;
    }
  }
  throw TestFailure('시간 안에 찾지 못함: $finder');
}

/// 보이도록 스크롤한 뒤 탭
Future<void> tapText(WidgetTester tester, String text, {int index = 0, bool scroll = true}) async {
  await tapFinder(tester, find.text(text), index: index, scroll: scroll);
}

Future<void> tapFinder(WidgetTester tester, Finder f, {int index = 0, bool scroll = true}) async {
  scroll ? await findOrScroll(tester, f) : await waitFor(tester, f);
  final target = f.at(index);
  if (scroll) await tester.ensureVisible(target);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(target, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 300));
}

/// 스낵바 안내를 확인하고 사라질 때까지 기다린다 (하단 버튼을 가리므로)
Future<void> expectSnack(WidgetTester tester, String message) async {
  await waitFor(tester, find.text(message));
  await waitGone(tester, find.byType(SnackBar), timeout: const Duration(seconds: 6));
}

/// 텍스트 입력 후 키보드를 닫는다
Future<void> typeInto(WidgetTester tester, Finder field, String text) async {
  await waitFor(tester, field);
  await tester.enterText(field, text);
  await tester.pump(const Duration(milliseconds: 200));
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 500));
}

/// 하단 탭 이동 (같은 글자의 버튼과 헷갈리지 않게 탭바 안에서만 찾는다)
Future<void> tapTab(WidgetTester tester, String label) async {
  await tapFinder(tester, find.descendant(of: find.byType(AppBottomNav), matching: find.text(label)), scroll: false);
}

/// 앱 시작 → 로그인 화면
Future<void> launchApp(WidgetTester tester) async {
  await tester.pumpWidget(const AptRoot());
  await waitFor(tester, find.text('Google로 계속하기'));
}

/// 기존 회원(Mock: Google)으로 로그인 → 홈
Future<void> signInExisting(WidgetTester tester) async {
  await launchApp(tester);
  await tapText(tester, 'Google로 계속하기');
  await waitFor(tester, find.text('저장된 장소'));
}

/// 렌더링 예외(overflow 등)가 없었는지
void expectNoErrors(WidgetTester tester) {
  final e = tester.takeException();
  if (e is FlutterError) debugPrint(e.toStringDeep());
  expect(e, isNull);
}
