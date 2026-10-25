import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/data_source.dart';
import '../../../app/di/repositories.dart';
import '../../course/presentation/course_draft_controller.dart';
import '../../course/presentation/recommendation_controller.dart';
import '../domain/auth_models.dart';

enum AuthStatus {
  /// 세션 복원 중
  unknown,
  unauthenticated,

  /// 신규 회원: 약관 → 프로필(소셜) 또는 계정 정보(아이디 가입) 진행 중
  signingUp,
  authenticated,
}

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.suggestedNickname,
    this.justSignedUp = false,
    this.idSignup = false,
  });

  final AuthStatus status;
  final AuthUser? user;
  final String? suggestedNickname;

  /// 가입 직후 — 가입 완료 화면(#4)을 보여준다.
  final bool justSignedUp;

  /// 아이디 가입 중 — 약관 다음에 프로필 대신 계정 정보 화면으로 간다.
  final bool idSignup;

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
    // 서버 모드: 서버가 소셜 로그인을 지원할 때까지 소셜 사용자는 Mock 데이터를 쓴다 (07 D28)
    if (result is SignedIn || result is NeedsSignup) ref.read(dataSourceProvider.notifier).useMockForSocial();
    _apply(result);
    return result;
  }

  Future<SignInResult> signInWithId(String login, String password) async {
    ref.read(dataSourceProvider.notifier).reset();
    final result = await ref.read(authRepositoryProvider).signInWithId(login: login, password: password);
    _apply(result);
    return result;
  }

  /// 로그인 화면의 회원가입 → 약관 → 계정 정보
  void startIdSignup() => state = const AuthState(status: AuthStatus.signingUp, idSignup: true);

  /// 계정 정보 입력 끝 → 가입(바로 로그인) → 가입 완료(#4). 실패하면 [ValidationFailure]를 그대로 던진다.
  Future<void> signUpWithId({required String login, required String password, required String nickname}) async {
    ref.read(dataSourceProvider.notifier).reset();
    final user = await ref
        .read(authRepositoryProvider)
        .signUpWithId(login: login, password: password, nickname: nickname);
    state = AuthState(status: AuthStatus.authenticated, user: user, justSignedUp: true);
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
    _clearSession();
    state = AuthState.signedOut;
  }

  /// 401 갱신 실패 — 로그인으로. 보류 중인 공유 URL/초대 토큰은 별도 provider에 남아 있다.
  void onSessionExpired() {
    if (state.status == AuthStatus.authenticated) {
      _clearSession();
      state = AuthState.signedOut;
    }
  }

  /// 다른 계정·다른 데이터 출처로 로그인할 때 이전 사람의 코스 초안·추천이 남지 않게 한다.
  void _clearSession() {
    ref.read(dataSourceProvider.notifier).reset();
    ref.invalidate(courseDraftProvider);
    ref.invalidate(recommendationProvider);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

/// 약관 목록 (서버)
final termsProvider = FutureProvider.autoDispose((ref) => ref.watch(authRepositoryProvider).fetchTerms());
