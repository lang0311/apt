/// 기능 플래그. (docs/02_APP_DEVELOPMENT.md §4)
abstract final class FeatureFlags {
  /// 이메일 로그인. 기본 false — 꺼져 있으면 진입점을 화면에 노출하지 않는다.
  static const emailAuthEnabled = bool.fromEnvironment('EMAIL_AUTH', defaultValue: false);
}
