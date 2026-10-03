enum SocialProvider {
  kakao('카카오'),
  google('Google'),
  apple('Apple');

  const SocialProvider(this.label);
  final String label;
}

class AuthUser {
  const AuthUser({required this.id, required this.nickname, this.handle, this.profileImageUrl});
  final String id;
  final String nickname;
  final String? handle;
  final String? profileImageUrl;
}

/// 소셜/이메일 로그인 결과. 서버 응답 → 이 타입으로의 매핑은 API 명세 기준 (NEEDS BACKEND).
sealed class SignInResult {
  const SignInResult();
}

/// 기존 회원 — 홈으로
class SignedIn extends SignInResult {
  const SignedIn(this.user);
  final AuthUser user;
}

/// 신규 — 약관 → 프로필
class NeedsSignup extends SignInResult {
  const NeedsSignup({this.suggestedNickname});
  final String? suggestedNickname;
}

/// 동일 이메일 기존 계정 (#5)
class AccountConflict extends SignInResult {
  const AccountConflict({required this.maskedEmail, required this.existingMethodLabel, required this.provider});
  final String maskedEmail;

  /// 예: "이메일로 가입한 계정"
  final String existingMethodLabel;
  final SocialProvider provider;
}

/// 사용자가 취소함 / 소셜 인증 실패 (#6)
class SignInCancelled extends SignInResult {
  const SignInCancelled();
}

class SignInFailed extends SignInResult {
  const SignInFailed(this.message);
  final String message;
}

/// 이메일 로그인 자격 증명 불일치 (#8) — 어느 쪽이 틀렸는지 구분하지 않는다.
class InvalidCredentials extends SignInResult {
  const InvalidCredentials();
}

/// 약관 항목 (서버의 약관 버전/URL)
class TermsItem {
  const TermsItem({required this.id, required this.title, required this.required, this.contentUrl});
  final String id;
  final String title;
  final bool required;
  final String? contentUrl;
}
