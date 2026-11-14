import 'package:apt/app/theme/app_theme.dart';
import 'package:apt/features/auth/presentation/pages/terms_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('약관 행은 선택 여부를 스크린리더에 알린다', (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(412, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(child: MaterialApp(theme: AppTheme.light(), home: const TermsPage())));
    await tester.pumpAndSettle();

    bool hasChecked() => tester.getSemantics(find.textContaining('전체 동의')).getSemanticsData().flagsCollection.hasCheckedState;
    bool isChecked() => tester.getSemantics(find.textContaining('전체 동의')).getSemanticsData().flagsCollection.isChecked;

    expect(hasChecked(), isTrue);
    expect(isChecked(), isFalse);
    await tester.tap(find.textContaining('전체 동의'));
    await tester.pumpAndSettle();
    expect(isChecked(), isTrue);
    semantics.dispose();
  });
}
