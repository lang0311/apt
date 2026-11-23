import 'package:apt/app/shell/app_shell.dart';
import 'package:apt/app/theme/app_theme.dart';
import 'package:apt/core/widgets/inputs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// 공통 위젯: 입력칸 이름표 위치, 하단 탭 글자 확대
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pump(WidgetTester tester, Widget child, {double scale = 1}) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(size: const Size(390, 844), textScaler: TextScaler.linear(scale)),
        child: Scaffold(body: child),
      ),
    ),
  );

  testWidgets('innerLabel은 칸 안 위쪽에 작은 이름표로', (tester) async {
    await pump(tester, const AppTextField(innerLabel: '아이디', hint: '아이디를 입력해 주세요'));
    final label = tester.getRect(find.text('아이디'));
    final box = tester.getRect(find.byType(AnimatedContainer));
    expect(box.contains(label.center), isTrue);
  });

  testWidgets('글자 크기 1.3배에서도 하단 탭이 넘치지 않는다', (tester) async {
    await pump(
      tester,
      Align(
        alignment: Alignment.bottomCenter,
        child: AppBottomNav(currentIndex: 0, onTap: (_) {}),
      ),
      scale: 1.3,
    );
    expect(tester.takeException(), isNull);
  });
}
