import 'package:apt/core/error/app_failure.dart';
import 'package:apt/dev/mock/mock_store.dart';
import 'package:apt/features/auth/data/auth_repositories.dart';
import 'package:apt/features/auth/data/server_mode_auth_repository.dart';
import 'package:apt/features/auth/domain/auth_models.dart';
import 'package:apt/features/auth/domain/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// 어느 메서드가 불렸는지만 기록한다.
class _Recorder implements AuthRepository {
  _Recorder(this.name);
  final String name;
  final calls = <String>[];

  @override
  Future<AuthUser?> restoreSession() async {
    calls.add('restore');
    return null;
  }

  @override
  Future<SignInResult> signInWithId({required String login, required String password}) async {
    calls.add('id');
    return const SignedIn(AuthUser(id: 'x', nickname: 'x'));
  }

  @override
  Future<AuthUser> signUpWithId({required String login, required String password, required String nickname}) async {
    calls.add('signup');
    return const AuthUser(id: 'x', nickname: 'x');
  }

  @override
  Future<SignInResult> signInWithSocial(SocialProvider provider) async {
    calls.add('social');
    return const SignInCancelled();
  }

  @override
  Future<AuthUser> linkExistingAccount(AccountConflict conflict) async => const AuthUser(id: 'x', nickname: 'x');
  @override
  Future<List<TermsItem>> fetchTerms() async {
    calls.add('terms');
    return const [];
  }

  @override
  Future<void> agreeTerms(Set<String> agreedIds) async => calls.add('agree');
  @override
  Future<AuthUser> completeProfile({required String nickname, String? imagePath}) async =>
      const AuthUser(id: 'x', nickname: 'x');
  @override
  Future<void> signOut() async => calls.add('signOut');
  @override
  Future<SignInResult> signInWithEmail({required String email, required String password}) async =>
      const InvalidCredentials();
}

void main() {
  group('IdSignupRules', () {
    test('팀 서버 규칙과 같이 검사한다', () {
      expect(IdSignupRules.validate(login: 'trip_jin', password: 'password1', nickname: '지상'), isEmpty);
      expect(IdSignupRules.validate(login: 'Trip_Jin', password: 'password1', nickname: '지상'), isEmpty);
      expect(IdSignupRules.validate(login: 'ab', password: 'password1', nickname: '지상').keys, ['login']);
      expect(IdSignupRules.validate(login: 'trip-jin', password: 'password1', nickname: '지상').keys, ['login']);
      expect(IdSignupRules.validate(login: 'trip_jin', password: 'short', nickname: '지상').keys, ['password']);
      expect(IdSignupRules.validate(login: 'trip_jin', password: 'password1', nickname: ' ').keys, ['nickname']);
    });
  });

  group('Mock 아이디 로그인·가입', () {
    final repo = MockAuthRepository(MockStore(), MockSocialAuthProvider());

    test('비밀번호 password1만 로그인된다', () async {
      expect(await repo.signInWithId(login: 'any', password: 'password1'), isA<SignedIn>());
      expect(await repo.signInWithId(login: 'any', password: 'wrong'), isA<InvalidCredentials>());
    });

    test('이미 있는 아이디는 아이디 칸 오류', () async {
      await expectLater(
        repo.signUpWithId(login: 'taken', password: 'password1', nickname: '지상'),
        throwsA(isA<ValidationFailure>().having((f) => f.fieldErrors['login'], 'login', IdSignupRules.loginTaken)),
      );
    });

    test('가입하면 아이디는 소문자로', () async {
      final user = await repo.signUpWithId(login: 'Trip_Jin', password: 'password1', nickname: ' 지상 ');
      expect(user.handle, 'trip_jin');
      expect(user.nickname, '지상');
    });
  });

  group('서버 모드 인증', () {
    late _Recorder server;
    late _Recorder mock;
    var social = false;
    late ServerModeAuthRepository repo;

    setUp(() {
      server = _Recorder('server');
      mock = _Recorder('mock');
      social = false;
      repo = ServerModeAuthRepository(server: server, mock: mock, isSocialSession: () => social);
    });

    test('아이디 로그인·가입·세션 복원은 서버로', () async {
      await repo.signInWithId(login: 'a', password: 'b');
      await repo.signUpWithId(login: 'a', password: 'b', nickname: 'c');
      await repo.restoreSession();
      expect(server.calls, ['id', 'signup', 'restore']);
      expect(mock.calls, isEmpty);
    });

    test('소셜 로그인·약관은 Mock으로', () async {
      await repo.signInWithSocial(SocialProvider.google);
      await repo.fetchTerms();
      await repo.agreeTerms({'service'});
      expect(mock.calls, ['social', 'terms', 'agree']);
      expect(server.calls, isEmpty);
    });

    test('로그아웃은 지금 로그인한 쪽으로', () async {
      await repo.signOut();
      social = true;
      await repo.signOut();
      expect(server.calls, ['signOut']);
      expect(mock.calls, ['signOut']);
    });
  });
}
