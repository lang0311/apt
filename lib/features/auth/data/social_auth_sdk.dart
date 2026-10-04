import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import '../../../core/config/env.dart';
import '../../../core/error/app_failure.dart';
import '../domain/auth_models.dart';
import '../domain/auth_repository.dart';

/// 실제 소셜 SDK (카카오 / Google). 키가 없는 공급자는 [fallback](Mock)으로 대체한다.
///
/// 돌려주는 토큰은 서버로 보낼 값이다 — 카카오는 access token, Google은 idToken.
/// NEEDS BACKEND: 서버가 어떤 토큰을 받아 검증하는지 확정 (카카오 OIDC idToken 사용 여부 포함).
/// Apple은 유료 멤버십 전까지 미도입 (FeatureFlags.appleAuthEnabled) → 항상 fallback.
class SdkSocialAuthProvider implements SocialAuthProvider {
  SdkSocialAuthProvider({required this.fallback});
  final SocialAuthProvider fallback;

  static Future<void>? _googleInit;

  /// `runApp` 전에 한 번 호출한다. Google은 첫 로그인 때 초기화한다.
  static void initSdks() {
    if (Env.kakaoNativeAppKey.isNotEmpty) KakaoSdk.init(nativeAppKey: Env.kakaoNativeAppKey);
  }

  static bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  static bool isConfigured(SocialProvider provider) => switch (provider) {
        SocialProvider.kakao => Env.kakaoNativeAppKey.isNotEmpty,
        SocialProvider.google =>
          Env.googleServerClientId.isNotEmpty && (!_isIOS || Env.googleIosClientId.isNotEmpty),
        SocialProvider.apple => false,
      };

  @override
  Future<String?> authenticate(SocialProvider provider) {
    if (!isConfigured(provider)) return fallback.authenticate(provider);
    return switch (provider) {
      SocialProvider.kakao => _kakao(),
      SocialProvider.google => _google(),
      SocialProvider.apple => fallback.authenticate(provider),
    };
  }

  /// 카카오톡이 있으면 카카오톡으로, 실패하면(미로그인 등) 카카오계정(웹)으로 로그인한다. 카카오 권장 흐름.
  Future<String?> _kakao() async {
    try {
      final OAuthToken token;
      if (await isKakaoTalkInstalled()) {
        try {
          token = await UserApi.instance.loginWithKakaoTalk();
        } on PlatformException catch (e) {
          if (e.code == 'CANCELED') return null;
          return (await UserApi.instance.loginWithKakaoAccount()).accessToken;
        }
      } else {
        token = await UserApi.instance.loginWithKakaoAccount();
      }
      return token.accessToken;
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') return null;
      debugPrint('[Kakao] $e');
      throw const SocialSdkFailure();
    } on KakaoAuthException catch (e) {
      if (e.error == AuthErrorCause.accessDenied) return null;
      debugPrint('[Kakao] $e');
      throw const SocialSdkFailure();
    } on KakaoException catch (e) {
      debugPrint('[Kakao] $e');
      throw const SocialSdkFailure();
    }
  }

  Future<String?> _google() async {
    final google = GoogleSignIn.instance;
    try {
      await (_googleInit ??= google.initialize(
        clientId: _isIOS ? Env.googleIosClientId : null,
        serverClientId: Env.googleServerClientId,
      ));
      final account = await google.authenticate();
      return account.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      debugPrint('[Google] $e');
      _googleInit = null; // 초기화 실패였다면 다음 시도에서 다시 초기화한다
      throw const SocialSdkFailure();
    }
  }
}
