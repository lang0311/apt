import 'package:apt/app/theme/app_theme.dart';
import 'package:apt/core/widgets/bottom_cta.dart';
import 'package:apt/core/widgets/overlays.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 하단 고정 버튼이 있으면 스낵바가 그 위에 뜨고, 없으면 기본 위치(화면 아래)에 뜬다.
void main() {
  Widget page({required bool withCta, Widget? bottomNav}) => MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          bottomNavigationBar: bottomNav,
          body: Builder(
            builder: (context) => Column(
              children: [
                Expanded(
                  child: Center(
                    child: TextButton(onPressed: () => showAppSnackBar(context, '3곳을 저장했어요'), child: const Text('띄우기')),
                  ),
                ),
                if (withCta) BottomCta(child: FilledButton(onPressed: () {}, child: const Text('완료'))),
              ],
            ),
          ),
        ),
      );

  Future<Rect> showAndMeasure(WidgetTester tester) async {
    await tester.tap(find.text('띄우기'));
    await tester.pumpAndSettle();
    // SnackBar 영역은 여백까지 포함하므로 실제로 보이는 카드(Material)를 잰다
    return tester.getRect(find.descendant(of: find.byType(SnackBar), matching: find.byType(Material)).first);
  }

  testWidgets('하단 버튼이 있으면 버튼 영역 위 8에 뜬다', (tester) async {
    await tester.pumpWidget(page(withCta: true));
    final snack = await showAndMeasure(tester);
    final cta = tester.getRect(find.byType(BottomCta));
    expect(cta.top - snack.bottom, moreOrLessEquals(8, epsilon: 0.5));
    expect(tester.getRect(find.text('완료')).bottom, lessThanOrEqualTo(cta.bottom));
  });

  testWidgets('하단 탭 위 화면에서도 하단 버튼 위에 뜬다', (tester) async {
    await tester.pumpWidget(page(withCta: true, bottomNav: const SizedBox(height: 64)));
    final snack = await showAndMeasure(tester);
    expect(tester.getRect(find.byType(BottomCta)).top - snack.bottom, moreOrLessEquals(8, epsilon: 0.5));
  });

  testWidgets('하단 버튼이 없으면 기본 위치(아래 여백 10)', (tester) async {
    await tester.pumpWidget(page(withCta: false));
    final snack = await showAndMeasure(tester);
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(screen.height - snack.bottom, moreOrLessEquals(10, epsilon: 0.5));
  });
}
