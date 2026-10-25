import 'package:apt/app/shell/app_shell.dart';
import 'package:apt/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('탭 순서는 홈 · 저장됨 · 코스 · 추출 · 마이, 누르면 각자의 branch로', (tester) async {
    final tapped = <int>[];
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(bottomNavigationBar: AppBottomNav(currentIndex: 1, onTap: tapped.add)),
    ));

    final labels = ['홈', '저장됨', '코스', '추출', '마이'];
    final xs = [for (final l in labels) tester.getCenter(find.text(l)).dx];
    expect(xs, [...xs]..sort(), reason: '왼쪽부터 순서대로');

    // 다섯 글자가 같은 줄에 있다
    final ys = {for (final l in labels) tester.getCenter(find.text(l)).dy};
    expect(ys.length, 1);

    for (final l in labels) {
      await tester.tap(find.text(l));
    }
    // branch: 홈 0 · 코스 1 · 저장됨 2 · 추출 3 · 마이 4
    expect(tapped, [0, 2, 1, 3, 4]);

    // 코스(branch 1)가 선택 상태
    expect(tester.getSemantics(find.bySemanticsLabel('코스')), matchesSemantics(label: '코스', isButton: true, hasSelectedState: true, isSelected: true, hasTapAction: true));
  });
}
