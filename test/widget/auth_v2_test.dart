import 'package:apt/app/theme/app_theme.dart';
import 'package:apt/features/auth/presentation/pages/id_signup_page.dart';
import 'package:apt/features/auth/presentation/pages/profile_setup_page.dart';
import 'package:apt/features/auth/presentation/pages/signup_done_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// 시안 v2 "2-1 회원가입 · 계정 정보", "3 프로필 설정", "4 가입 완료"
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pump(WidgetTester tester, Widget page) => tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(theme: AppTheme.light(), home: page),
    ),
  );

  testWidgets('회원가입: 제목 "계정을 만들어 주세요" + 2 / 2, 비밀번호가 짧으면 지금 글자 수', (tester) async {
    await pump(tester, const IdSignupPage());
    expect(find.text('계정을 만들어 주세요'), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), 'sky2026');
    await tester.pump();
    expect(find.text('8자 이상 입력해 주세요 (지금 7자)'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), 'sky20260');
    await tester.pump();
    expect(find.textContaining('지금 '), findsNothing);
  });

  testWidgets('프로필 설정은 닉네임만 (취향 칸 없음)', (tester) async {
    await pump(tester, const ProfileSetupPage());
    expect(find.text('어떻게 불러\n드릴까요?'), findsOneWidget);
    expect(find.text('추천에 쓸 취향'), findsNothing);
    expect(find.text('닉네임'), findsOneWidget);
  });

  testWidgets('가입 완료: 첫 저장 방법을 정거장 세 개로', (tester) async {
    await pump(tester, const SignupDonePage());
    expect(find.text('릴스에서 ⋯ 누르기'), findsOneWidget);
    expect(find.text('공유 → APT 고르기'), findsOneWidget);
    expect(find.text('찾은 장소 확인하고 저장'), findsOneWidget);
  });
}
