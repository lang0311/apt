import '../../../core/error/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../../../dev/mock/mock_store.dart';
import '../domain/auth_models.dart';
import '../domain/auth_repository.dart';

/// Mock 소셜 SDK. 항상 토큰을 돌려준다.
class MockSocialAuthProvider implements SocialAuthProvider {
  @override
  Future<String?> authenticate(SocialProvider provider) async => 'mock-${provider.name}-token';
}

/// Mock 인증. 흐름 확인용으로 공급자별 결과를 다르게 준다.
/// - 카카오: 신규 회원 → 약관/프로필
/// - Google: 기존 회원 → 홈
/// - Apple: 동일 이메일 기존 계정 → 계정 충돌(#5)
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
    final token = await _social.authenticate(provider);
    if (token == null) return const SignInCancelled();
    try {
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
}
