import 'auth_models.dart';

/// 인증. 아이디·비밀번호 로그인 + 소셜 로그인 (07 D28). 이메일은 틀만 (FeatureFlags.emailAuthEnabled).
abstract interface class AuthRepository {
  /// 저장된 토큰으로 세션 복원. 없으면 null.
  Future<AuthUser?> restoreSession();

  /// 소셜 SDK 로그인 → 서버 토큰 교환 → 신규/기존/충돌 판별
  Future<SignInResult> signInWithSocial(SocialProvider provider);

  /// 계정 충돌(#5)에서 기존 계정과 연결
  Future<AuthUser> linkExistingAccount(AccountConflict conflict);

  Future<List<TermsItem>> fetchTerms();

  Future<void> agreeTerms(Set<String> agreedIds);

  /// 닉네임 규칙/중복은 서버 기준. 실패 시 ValidationFailure.
  Future<AuthUser> completeProfile({required String nickname});

  Future<void> signOut();

  /// 아이디·비밀번호 로그인. 틀리면 [InvalidCredentials] (어느 쪽이 틀렸는지 구분하지 않는다).
  Future<SignInResult> signInWithId({required String login, required String password});

  /// 아이디 가입. 가입하면 바로 로그인된다. 칸별 오류는 [ValidationFailure.fieldErrors]
  /// (`login`·`password`·`nickname` 키)로 준다.
  Future<AuthUser> signUpWithId({required String login, required String password, required String nickname});

  /// 이메일 로그인 (stub — flag off)
  Future<SignInResult> signInWithEmail({required String email, required String password});
}

/// 소셜 SDK 래퍼. 카카오/Google/Apple SDK를 도입하면 이것만 구현한다.
/// NEEDS: 카카오 네이티브 앱 키, Google OAuth 클라이언트, Apple Sign In capability.
abstract interface class SocialAuthProvider {
  /// SDK 인증 후 서버로 보낼 토큰. 사용자가 취소하면 null.
  Future<String?> authenticate(SocialProvider provider);
}
