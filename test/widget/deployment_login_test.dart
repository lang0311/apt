import 'package:apt/app/theme/app_theme.dart';
import 'package:apt/core/config/feature_flags.dart';
import 'package:apt/features/auth/presentation/pages/social_login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  testWidgets('deployment login respects signup and social flags', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const SocialLoginPage(),
        ),
      ),
    );
    expect(find.text('로그인'), findsOneWidget);
    expect(
      find.text('회원가입'),
      FeatureFlags.publicSignup ? findsOneWidget : findsNothing,
    );
    expect(
      find.text('간편 로그인'),
      FeatureFlags.socialAuth ? findsOneWidget : findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
