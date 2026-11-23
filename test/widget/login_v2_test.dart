import 'package:apt/app/theme/app_colors.dart';
import 'package:apt/app/theme/app_theme.dart';
import 'package:apt/app/di/repositories.dart';
import 'package:apt/features/auth/domain/auth_models.dart';
import 'package:apt/features/auth/presentation/pages/social_login_page.dart';
import 'package:apt/features/auth/presentation/widgets/route_hero.dart';
import 'package:apt/features/auth/domain/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// 시안 v2 "1 로그인 · 아이디 / 입력 오류"
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('노선 그림은 정거장 세 개, 마지막은 AI 정거장(✦)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: RouteHero()),
      ),
    );
    expect(find.text('릴스에서 본 카페'), findsOneWidget);
    expect(find.text('서울숲 산책'), findsOneWidget);
    expect(find.text('✦ AI가 고른 저녁'), findsOneWidget);
  });

  testWidgets('로그인 화면: 노선 그림 · 제목 · 칸 안 이름표 · 회원가입', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(_WrongPassword())],
        child: MaterialApp(theme: AppTheme.light(), home: const SocialLoginPage()),
      ),
    );
    expect(find.byType(RouteHero), findsOneWidget);
    expect(find.text('가고 싶은 곳을,\n하나의 코스로.'), findsOneWidget);
    expect(find.text('아이디'), findsOneWidget);
    expect(find.text('비밀번호'), findsOneWidget);
    expect(find.text('회원가입'), findsOneWidget);
  });

  testWidgets('틀리면 두 칸 모두 빨간 테두리 + "아이디 또는 비밀번호가 맞지 않아요."', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(_WrongPassword())],
        child: MaterialApp(theme: AppTheme.light(), home: const SocialLoginPage()),
      ),
    );
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'langi');
    await tester.enterText(fields.at(1), 'wrongpass');
    await tester.ensureVisible(find.text('로그인'));
    await tester.pump();
    await tester.tap(find.text('로그인'));
    await tester.pumpAndSettle();

    expect(find.text('아이디 또는 비밀번호가 맞지 않아요.'), findsOneWidget);
    final boxes = tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer)).toList();
    final red = boxes.where((b) => ((b.decoration as BoxDecoration?)?.border as Border?)?.top.color == AppColors.danger);
    expect(red.length, 2);
  });
}

class _WrongPassword implements AuthRepository {
  @override
  Future<SignInResult> signInWithId({required String login, required String password}) async => const InvalidCredentials();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
