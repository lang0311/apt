/// 기능 플래그. (docs/02_APP_DEVELOPMENT.md §4)
abstract final class FeatureFlags {
  /// 이메일 로그인. 기본 false — 꺼져 있으면 진입점을 화면에 노출하지 않는다.
  static const emailAuthEnabled = bool.fromEnvironment('EMAIL_AUTH', defaultValue: false);

  /// Apple 로그인. 기본 false — Apple Developer 유료 멤버십 전까지 iOS/Android 모두 버튼을 숨긴다.
  /// 켜려면 `sign_in_with_apple` 도입 + Sign in with Apple capability가 필요하다.
  static const appleAuthEnabled = bool.fromEnvironment('APPLE_AUTH', defaultValue: false);

  /// 취향을 칩으로 직접 고르기. 리디자인 v2(2026-11-21 사용자 결정): 지금은 기능이 없어 Mock에서도 끄고,
  /// 저장한 장소로 취향을 읽는 화면만 쓴다. 서버가 직접 고르는 취향을 지원하면 켠다.
  static const manualTasteEnabled = bool.fromEnvironment('MANUAL_TASTE', defaultValue: false);
}
