import 'auth_models.dart';

/// 인증. 소셜이 기본, 이메일은 틀만 (FeatureFlags.emailAuthEnabled).
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
  Future<AuthUser> completeProfile({required String nickname, String? imagePath});

  Future<void> signOut();

  /// 이메일 로그인 (stub — flag off)
  Future<SignInResult> signInWithEmail({required String email, required String password});
}

/// 소셜 SDK 래퍼. 카카오/Google/Apple SDK를 도입하면 이것만 구현한다.
/// NEEDS: 카카오 네이티브 앱 키, Google OAuth 클라이언트, Apple Sign In capability.
abstract interface class SocialAuthProvider {
  /// SDK 인증 후 서버로 보낼 토큰. 사용자가 취소하면 null.
  Future<String?> authenticate(SocialProvider provider);
}
