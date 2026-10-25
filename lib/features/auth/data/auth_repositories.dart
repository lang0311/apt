import '../../../core/error/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../../../dev/mock/mock_store.dart';
import '../domain/auth_models.dart';
import '../domain/auth_repository.dart';

/// Mock 소셜 SDK. 항상 토큰을 돌려준다. 키가 없는 공급자는 [SdkSocialAuthProvider]가 이것으로 대체한다.
class MockSocialAuthProvider implements SocialAuthProvider {
  @override
  Future<String?> authenticate(SocialProvider provider) async => 'mock-${provider.name}-token';
}

/// Mock 인증. 흐름 확인용으로 공급자별 결과를 다르게 준다.
/// - 카카오: 신규 회원 → 약관/프로필
/// - Google: 기존 회원 → 홈
/// - Apple: 동일 이메일 기존 계정 → 계정 충돌(#5) (Apple 버튼은 FeatureFlags.appleAuthEnabled일 때만 보임)
/// - MOCK_SCENARIO=error: 소셜 인증 오류(#6)
class MockAuthRepository implements AuthRepository {
  MockAuthRepository(this._store, this._social);
  final MockStore _store;
  final SocialAuthProvider _social;

  static const _user = AuthUser(id: 'u1', nickname: '김서연', handle: '@jin');

  @override
  Future<AuthUser?> restoreSession() async => null;

  @override
  Future<SignInResult> signInWithSocial(SocialProvider provider) async {
    try {
      final token = await _social.authenticate(provider);
      if (token == null) return const SignInCancelled();
      return await _store.behavior.mutate<SignInResult>(() => switch (provider) {
            SocialProvider.kakao => const NeedsSignup(suggestedNickname: '여행하는 지상'),
            SocialProvider.google => const SignedIn(_user),
            SocialProvider.apple => AccountConflict(
                maskedEmail: 'jis***@gmail.com',
                existingMethodLabel: '이메일로 가입한 계정',
                provider: provider,
              ),
          });
    } on AppFailure catch (e) {
      return SignInFailed(e.message);
    }
  }

  @override
  Future<AuthUser> linkExistingAccount(AccountConflict conflict) => _store.behavior.mutate(() => _user);

  @override
  Future<List<TermsItem>> fetchTerms() => _store.behavior.query(() => const [
        TermsItem(id: 'age14', title: '만 14세 이상입니다.', required: true),
        TermsItem(id: 'service', title: '서비스 이용약관 동의', required: true, contentUrl: 'https://example.com/terms'),
        TermsItem(id: 'privacy', title: '개인정보 수집·이용 동의', required: true, contentUrl: 'https://example.com/privacy'),
        TermsItem(id: 'marketing', title: '맞춤 장소 추천 정보 수신', required: false),
      ]);

  @override
  Future<void> agreeTerms(Set<String> agreedIds) => _store.behavior.mutate(() {});

  @override
  Future<AuthUser> completeProfile({required String nickname, String? imagePath}) =>
      _store.behavior.mutate(() {
        final n = nickname.trim();
        if (n.length < 2) throw const ValidationFailure('닉네임은 2자 이상 입력해주세요.');
        if (n == '관리자') throw const ValidationFailure('이미 사용 중인 닉네임이에요.');
        return AuthUser(id: 'u2', nickname: n);
      });

  @override
  Future<void> signOut() async {}

  @override
  Future<SignInResult> signInWithEmail({required String email, required String password}) =>
      _store.behavior.mutate(() => password == 'password1' ? const SignedIn(_user) : const InvalidCredentials());

  /// Mock 규칙: 비밀번호가 `password1`이면 로그인, 아니면 불일치.
  @override
  Future<SignInResult> signInWithId({required String login, required String password}) =>
      _store.behavior.mutate(() => password == 'password1' ? const SignedIn(_user) : const InvalidCredentials());

  /// Mock 규칙: 아이디 `taken`은 이미 사용 중. 형식 검사는 팀 서버 규칙과 같다.
  @override
  Future<AuthUser> signUpWithId({required String login, required String password, required String nickname}) =>
      _store.behavior.mutate(() {
        if (login.trim().toLowerCase() == 'taken') {
          throw const ValidationFailure(IdSignupRules.loginTaken, fieldErrors: {'login': IdSignupRules.loginTaken});
        }
        final errors = IdSignupRules.validate(login: login, password: password, nickname: nickname);
        if (errors.isNotEmpty) throw ValidationFailure(errors.values.first, fieldErrors: errors);
        return AuthUser(id: 'u3', nickname: nickname.trim(), handle: login.trim().toLowerCase());
      });
}

/// 아이디 가입 입력 규칙 (팀 서버 `platform_store.register`와 같게). 문구는 화면 말투(해요체).
abstract final class IdSignupRules {
  static final _login = RegExp(r'^[a-z0-9_]{3,30}$');
  static const loginHelp = '영문 소문자·숫자·밑줄 3~30자';
  static const passwordHelp = '8자 이상';
  static const loginInvalid = '아이디는 영문 소문자·숫자·밑줄 3~30자로 입력해주세요.';
  static const loginTaken = '이미 사용 중인 아이디예요.';
  static const passwordInvalid = '비밀번호는 8자 이상 입력해주세요.';
  static const nicknameEmpty = '닉네임을 입력해주세요.';

  /// 칸별 오류. 비어 있으면 통과. 아이디는 서버처럼 소문자로 바꿔 검사한다.
  static Map<String, String> validate({required String login, required String password, required String nickname}) => {
        if (!_login.hasMatch(login.trim().toLowerCase())) 'login': loginInvalid,
        if (password.length < 8 || password.length > 128) 'password': passwordInvalid,
        if (nickname.trim().isEmpty || nickname.trim().length > 60) 'nickname': nicknameEmpty,
      };
}

// NEEDS BACKEND: 소셜 토큰 교환, 신규/기존 판별, 계정 충돌 응답, 약관 버전/동의, 닉네임 규칙, 토큰 갱신
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._client, this._tokens, this._social);
  // ignore: unused_field
  final ApiClient _client;
  final TokenStorage _tokens;
  // ignore: unused_field
  final SocialAuthProvider _social;

  static const _f = NotImplementedFailure('로그인');

  @override
  Future<AuthUser?> restoreSession() async {
    final token = await _tokens.readAccessToken();
    if (token == null) return null;
    throw _f; // NEEDS BACKEND: 내 정보 조회 API
  }

  @override
  Future<SignInResult> signInWithSocial(SocialProvider provider) async => throw _f;
  @override
  Future<AuthUser> linkExistingAccount(AccountConflict conflict) async => throw _f;
  @override
  Future<List<TermsItem>> fetchTerms() async => throw _f;
  @override
  Future<void> agreeTerms(Set<String> agreedIds) async => throw _f;
  @override
  Future<AuthUser> completeProfile({required String nickname, String? imagePath}) async => throw _f;

  @override
  Future<void> signOut() => _tokens.clear();

  /// 이메일 로그인은 틀만 (FeatureFlags.emailAuthEnabled=false)
  @override
  Future<SignInResult> signInWithEmail({required String email, required String password}) async => throw _f;

  @override
  Future<SignInResult> signInWithId({required String login, required String password}) async => throw _f;
  @override
  Future<AuthUser> signUpWithId({required String login, required String password, required String nickname}) async =>
      throw _f;
}
