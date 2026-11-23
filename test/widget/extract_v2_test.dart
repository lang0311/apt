import 'package:apt/app/theme/app_colors.dart';
import 'package:apt/app/theme/app_theme.dart';
import 'package:apt/features/extraction/presentation/pages/link_input_page.dart';
import 'package:apt/features/extraction/presentation/widgets/extracted_place_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// 시안 v2 "10 장소 추가": 링크 칸 → 지도에서 찾기 → 릴스 안내 판 순서, 링크 줄은 채움 바탕
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('링크 입력 칸이 맨 위, 그 아래 지도에서 찾기, 그 아래 릴스 안내', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light(), home: const LinkInputPage()),
      ),
    );
    await tester.pump();
    final link = tester.getTopLeft(find.byType(TextField)).dy;
    final map = tester.getTopLeft(find.text('지도에서 찾기')).dy;
    final reels = tester.getTopLeft(find.text('릴스에서 바로 저장하는 게 가장 빨라요')).dy;
    expect(link < map, isTrue);
    expect(map < reels, isTrue);
    // Mock 저장소의 지연 타이머가 끝나게 기다린다
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('링크 줄은 테두리 없는 채움 바탕', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: ExtractSourceRow(leading: LinkTile(), child: Text('링크')),
        ),
      ),
    );
    final box = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).decoration as BoxDecoration;
    expect(box.color, AppColors.fill);
    expect((box.border as Border?)?.top.color ?? Colors.transparent, Colors.transparent);
  });
}
