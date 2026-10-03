import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/repositories.dart';
import '../domain/auth_models.dart';

enum AuthStatus {
  /// 세션 복원 중
  unknown,
  unauthenticated,

  /// 신규 회원: 약관/프로필 진행 중
  signingUp,
  authenticated,
}

class AuthState {
  const AuthState({required this.status, this.user, this.suggestedNickname, this.justSignedUp = false});

  final AuthStatus status;
  final AuthUser? user;
  final String? suggestedNickname;

  /// 가입 직후 — 가입 완료 화면(#4)을 보여준다.
  final bool justSignedUp;

  static const unknown = AuthState(status: AuthStatus.unknown);
  static const signedOut = AuthState(status: AuthStatus.unauthenticated);
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(_restore);
    return AuthState.unknown;
  }

  Future<void> _restore() async {
    try {
      final user = await ref.read(authRepositoryProvider).restoreSession();
      state = user == null ? AuthState.signedOut : AuthState(status: AuthStatus.authenticated, user: user);
    } catch (_) {
      state = AuthState.signedOut;
    }
  }

  /// 결과에 따라 상태를 바꾸고, 화면 분기(충돌/오류)는 호출 측이 결과를 보고 처리한다.
  Future<SignInResult> signInWithSocial(SocialProvider provider) async {
    final result = await ref.read(authRepositoryProvider).signInWithSocial(provider);
    _apply(result);
    return result;
  }

  Future<SignInResult> signInWithEmail(String email, String password) async {
    final result = await ref.read(authRepositoryProvider).signInWithEmail(email: email, password: password);
    _apply(result);
    return result;
  }

  void _apply(SignInResult result) {
    switch (result) {
      case SignedIn(:final user):
        state = AuthState(status: AuthStatus.authenticated, user: user);
      case NeedsSignup(:final suggestedNickname):
        state = AuthState(status: AuthStatus.signingUp, suggestedNickname: suggestedNickname);
      default:
        break;
    }
  }

  Future<void> linkExistingAccount(AccountConflict conflict) async {
    final user = await ref.read(authRepositoryProvider).linkExistingAccount(conflict);
    state = AuthState(status: AuthStatus.authenticated, user: user);
  }

  Future<void> agreeTerms(Set<String> ids) => ref.read(authRepositoryProvider).agreeTerms(ids);

  Future<void> completeProfile(String nickname) async {
    final user = await ref.read(authRepositoryProvider).completeProfile(nickname: nickname);
    state = AuthState(status: AuthStatus.authenticated, user: user, justSignedUp: true);
  }

  /// 가입 완료(#4) → 시작하기
  void finishOnboarding() => state = AuthState(status: AuthStatus.authenticated, user: state.user);

  /// 가입 도중 로그인 화면으로 돌아갈 때
  void cancelSignup() => state = AuthState.signedOut;

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = AuthState.signedOut;
  }

  /// 401 갱신 실패 — 로그인으로. 보류 중인 공유 URL/초대 토큰은 별도 provider에 남아 있다.
  void onSessionExpired() {
    if (state.status == AuthStatus.authenticated) state = AuthState.signedOut;
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

/// 약관 목록 (서버)
final termsProvider = FutureProvider.autoDispose((ref) => ref.watch(authRepositoryProvider).fetchTerms());
