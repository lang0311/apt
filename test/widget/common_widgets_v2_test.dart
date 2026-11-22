import 'package:apt/app/shell/app_shell.dart';
import 'package:lucide_icons_flutter/lucide_icons_500.dart';
import 'package:apt/app/theme/app_colors.dart';
import 'package:apt/app/theme/app_spacing.dart';
import 'package:apt/app/theme/app_theme.dart';
import 'package:apt/core/widgets/buttons.dart';
import 'package:apt/core/widgets/chips.dart';
import 'package:apt/core/widgets/inputs.dart';
import 'package:apt/core/widgets/surfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// 리디자인 v2 공통 위젯 (시안 v2: 상자 없는 섹션 · 채움 버튼/칩/입력칸 · 다섯 칸 같은 하단 탭)
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

  testWidgets('SectionCard는 테두리 · 바탕 상자 없이 제목 + 내용만', (tester) async {
    await pump(tester, const SectionCard(title: '지역별로 시작하기', child: Text('내용')));
    final boxes = tester.widgetList<Container>(find.descendant(of: find.byType(SectionCard), matching: find.byType(Container)));
    for (final c in boxes) {
      final d = c.decoration;
      expect(d is BoxDecoration ? d.border : null, isNull);
    }
    expect(find.text('지역별로 시작하기'), findsOneWidget);
  });

  testWidgets('SectionGap은 높이 10 채움 띠', (tester) async {
    await pump(tester, const Column(children: [SectionGap()]));
    expect(tester.getSize(find.byType(SectionGap)).height, AppSpacing.sectionGap);
    final box = tester.widget<ColoredBox>(find.descendant(of: find.byType(SectionGap), matching: find.byType(ColoredBox)));
    expect(box.color, AppColors.fill);
  });

  testWidgets('보조 버튼(secondary)은 채움 바탕 + 잉크 글자, 높이 54', (tester) async {
    await pump(tester, AppButton(label: '다시 추천', variant: AppButtonVariant.secondary, onPressed: () {}));
    final m = tester.widget<Material>(find.descendant(of: find.byType(AppButton), matching: find.byType(Material)).first);
    expect(m.color, AppColors.fill);
    expect(tester.getSize(find.byType(AppButton)).height, 54);
  });

  testWidgets('고른 칩은 잉크 채움, 안 고른 칩은 채움색, 높이 36', (tester) async {
    await pump(
      tester,
      Row(
        children: [
          AppChip(label: '카페', selected: true, onTap: () {}),
          AppChip(label: '맛집', selected: false, onTap: () {}),
        ],
      ),
    );
    final ms = tester.widgetList<Material>(find.descendant(of: find.byType(AppChip), matching: find.byType(Material))).toList();
    expect(ms[0].color, AppColors.textPrimary);
    expect(ms[1].color, AppColors.fill);
    expect(tester.getSize(find.byType(AppChip).first).height, 36);
  });

  testWidgets('입력칸은 채움 바탕 · 테두리 없음, 오류면 빨간 2px', (tester) async {
    await pump(
      tester,
      const Column(
        children: [
          AppTextField(hint: '아이디'),
          AppTextField(hint: '비밀번호', hasError: true),
        ],
      ),
    );
    final boxes = tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer)).toList();
    final normal = boxes[0].decoration as BoxDecoration;
    final error = boxes[1].decoration as BoxDecoration;
    expect(normal.color, AppColors.fill);
    expect((normal.border as Border?)?.top.color ?? Colors.transparent, Colors.transparent);
    expect((error.border! as Border).top.color, AppColors.danger);
    expect((error.border! as Border).top.width, 2);
  });

  testWidgets('innerLabel은 칸 안 위쪽에 작은 이름표로', (tester) async {
    await pump(tester, const AppTextField(innerLabel: '아이디', hint: '아이디를 입력해 주세요'));
    final label = tester.getRect(find.text('아이디'));
    final box = tester.getRect(find.byType(AnimatedContainer));
    expect(box.contains(label.center), isTrue);
  });

  testWidgets('하단 탭 다섯 칸은 아이콘 높이가 같고(가운데 띄운 버튼 없음) 활성 색은 잉크', (tester) async {
    await pump(
      tester,
      Align(
        alignment: Alignment.bottomCenter,
        child: AppBottomNav(currentIndex: 1, onTap: (_) {}),
      ),
    );
    final icons = tester.widgetList<Icon>(find.descendant(of: find.byType(AppBottomNav), matching: find.byType(Icon))).toList();
    expect(icons.length, 5);
    final ys = {
      for (final i in find.descendant(of: find.byType(AppBottomNav), matching: find.byType(Icon)).evaluate())
        tester.getCenter(find.byWidget(i.widget)).dy.round(),
    };
    expect(ys.length, 1);
    final active = icons.firstWhere((i) => i.icon == LucideIcons500.route);
    expect(active.color, AppColors.textPrimary);
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
