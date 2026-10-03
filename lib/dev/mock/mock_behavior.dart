import '../../core/config/env.dart';
import '../../core/error/app_failure.dart';

enum MockScenario { normal, empty, error }

/// Mock 응답 시뮬레이션: 지연 · 빈 응답 · 오류 (상태 UI 검증용, docs/06 §6)
class MockBehavior {
  const MockBehavior({required this.scenario, required this.latency});

  factory MockBehavior.fromEnv() => MockBehavior(
        scenario: MockScenario.values.firstWhere(
          (s) => s.name == Env.mockScenario,
          orElse: () => MockScenario.normal,
        ),
        latency: const Duration(milliseconds: Env.mockLatencyMs),
      );

  final MockScenario scenario;
  final Duration latency;

  /// 조회 응답. empty 시나리오에서는 [empty]를 돌려준다.
  Future<T> query<T>(T Function() data, {T Function()? empty, Duration? latency}) async {
    await Future<void>.delayed(latency ?? this.latency);
    if (scenario == MockScenario.error) throw const ServerFailure();
    if (scenario == MockScenario.empty && empty != null) return empty();
    return data();
  }

  /// 변경 요청. error 시나리오에서만 실패한다.
  Future<T> mutate<T>(T Function() action, {Duration? latency}) async {
    await Future<void>.delayed(latency ?? this.latency);
    if (scenario == MockScenario.error) throw const ServerFailure();
    return action();
  }
}
