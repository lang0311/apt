/// 실행 환경 값. `--dart-define`으로 주입한다.
///
/// ```
/// flutter run --dart-define=USE_MOCK=true --dart-define=MOCK_SCENARIO=normal
/// flutter run --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=https://...
/// ```
abstract final class Env {
  /// Mock Repository 사용 여부. API 명세 수령 전까지 기본 true.
  static const useMock = bool.fromEnvironment('USE_MOCK', defaultValue: true);

  /// Mock 응답 시나리오: normal | empty | error (상태 UI 검증용)
  static const mockScenario = String.fromEnvironment('MOCK_SCENARIO', defaultValue: 'normal');

  /// Mock 응답 지연(ms)
  static const mockLatencyMs = int.fromEnvironment('MOCK_LATENCY_MS', defaultValue: 600);

  // NEEDS BACKEND: 개발/스테이징 서버 주소
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');

  // 키 값은 `--dart-define-from-file=config/dev.json`으로 주입한다 (예시: config/dev.example.json, 커밋 금지).

  /// Naver Cloud Platform 지도 클라이언트 ID (비어 있으면 지도 미리보기 위젯 사용)
  static const naverMapClientId = String.fromEnvironment('NAVER_MAP_CLIENT_ID', defaultValue: '');

  /// 카카오 네이티브 앱 키 (비어 있으면 카카오 로그인은 Mock SDK). Android scheme도 이 값으로 만든다.
  static const kakaoNativeAppKey = String.fromEnvironment('KAKAO_NATIVE_APP_KEY', defaultValue: '');

  /// Google OAuth "웹" 클라이언트 ID. Android 로그인과 서버의 idToken 검증(aud)에 쓴다.
  static const googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID', defaultValue: '');

  /// Google OAuth iOS 클라이언트 ID (iOS 전용)
  static const googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID', defaultValue: '');
}
