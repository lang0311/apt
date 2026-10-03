import 'package:apt/app/router.dart';
import 'package:apt/app/routes.dart';
import 'package:apt/features/auth/domain/auth_models.dart';
import 'package:apt/features/auth/presentation/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const user = AuthUser(id: 'u', nickname: 'n');
  const signedIn = AuthState(status: AuthStatus.authenticated, user: user);

  group('authRedirect', () {
    test('세션 복원 중에는 스플래시', () {
      expect(authRedirect(AuthState.unknown, AppRoutes.home), AppRoutes.splash);
      expect(authRedirect(AuthState.unknown, AppRoutes.splash), isNull);
    });

    test('비로그인은 로그인으로, 초대 링크는 허용', () {
      expect(authRedirect(AuthState.signedOut, AppRoutes.home), AppRoutes.login);
      expect(authRedirect(AuthState.signedOut, AppRoutes.loginConflict), isNull);
      expect(authRedirect(AuthState.signedOut, '/invites/abc'), isNull);
    });

    test('이메일 로그인은 flag off면 진입 불가', () {
      expect(authRedirect(AuthState.signedOut, AppRoutes.loginEmail), AppRoutes.login);
    });

    test('가입 중에는 약관/프로필/취향 설정만', () {
      const signingUp = AuthState(status: AuthStatus.signingUp);
      expect(authRedirect(signingUp, AppRoutes.home), AppRoutes.signupTerms);
      expect(authRedirect(signingUp, AppRoutes.signupProfile), isNull);
      expect(authRedirect(signingUp, AppRoutes.preferences), isNull);
    });

    test('가입 직후에는 가입 완료 화면', () {
      const just = AuthState(status: AuthStatus.authenticated, user: user, justSignedUp: true);
      expect(authRedirect(just, AppRoutes.signupProfile), AppRoutes.signupDone);
      expect(authRedirect(just, AppRoutes.signupDone), isNull);
    });

    test('로그인 상태에서 로그인/가입 화면은 홈으로', () {
      expect(authRedirect(signedIn, AppRoutes.login), AppRoutes.home);
      expect(authRedirect(signedIn, AppRoutes.signupTerms), AppRoutes.home);
      expect(authRedirect(signedIn, AppRoutes.saved), isNull);
    });
  });
}
