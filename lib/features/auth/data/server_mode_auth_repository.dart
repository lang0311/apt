import '../domain/auth_models.dart';
import '../domain/auth_repository.dart';

/// 서버 모드(`APT_BACKEND=true`) 인증 (07 D28).
/// 아이디·비밀번호는 팀 서버에서 확인하고, 소셜 로그인·약관·프로필은 서버가 지원할 때까지 Mock으로 진행한다.
/// 소셜로 로그인하면 앱 데이터도 Mock을 쓴다 ([dataSourceProvider]).
///
/// NEEDS BACKEND: 소셜 토큰 교환(서버 세션 발급), 약관 목록·동의 저장, 프로필 저장
class ServerModeAuthRepository implements AuthRepository {
  ServerModeAuthRepository({required this.server, required this.mock, required this.isSocialSession});

  final AuthRepository server;
  final AuthRepository mock;

  /// 지금 로그인이 소셜(Mock)인지. 로그아웃을 어느 쪽에 보낼지 정한다.
  final bool Function() isSocialSession;

  @override
  Future<AuthUser?> restoreSession() => server.restoreSession();

  @override
  Future<SignInResult> signInWithId({required String login, required String password}) =>
      server.signInWithId(login: login, password: password);

  @override
  Future<AuthUser> signUpWithId({required String login, required String password, required String nickname}) =>
      server.signUpWithId(login: login, password: password, nickname: nickname);

  @override
  Future<SignInResult> signInWithSocial(SocialProvider provider) => mock.signInWithSocial(provider);

  @override
  Future<AuthUser> linkExistingAccount(AccountConflict conflict) => mock.linkExistingAccount(conflict);

  @override
  Future<List<TermsItem>> fetchTerms() => mock.fetchTerms();

  @override
  Future<void> agreeTerms(Set<String> agreedIds) => mock.agreeTerms(agreedIds);

  @override
  Future<AuthUser> completeProfile({required String nickname, String? imagePath}) =>
      mock.completeProfile(nickname: nickname, imagePath: imagePath);

  @override
  Future<void> signOut() => isSocialSession() ? mock.signOut() : server.signOut();

  @override
  Future<SignInResult> signInWithEmail({required String email, required String password}) =>
      server.signInWithEmail(email: email, password: password);
}
