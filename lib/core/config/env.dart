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

  // NEEDS: Naver Cloud Platform 지도 클라이언트 ID (비어 있으면 지도 미리보기 위젯 사용)
  static const naverMapClientId = String.fromEnvironment('NAVER_MAP_CLIENT_ID', defaultValue: '');
}
