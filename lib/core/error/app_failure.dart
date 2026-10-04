/// 앱 전역 실패 타입. 서버 응답(HTTP 상태/에러 코드)을 화면이 쓰기 좋은 형태로 바꾼 것.
/// 도메인별 실패(추출 실패 사유 등)는 각 feature에서 별도로 정의한다.
sealed class AppFailure implements Exception {
  const AppFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

class NetworkFailure extends AppFailure {
  const NetworkFailure([super.message = '인터넷 연결을 확인해주세요.']);
}

class TimeoutFailure extends AppFailure {
  const TimeoutFailure([super.message = '응답이 늦어지고 있어요. 잠시 후 다시 시도해주세요.']);
}

class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure([super.message = '다시 로그인해주세요.']);
}

class ForbiddenFailure extends AppFailure {
  const ForbiddenFailure([super.message = '접근 권한이 없어요.']);
}

class NotFoundFailure extends AppFailure {
  const NotFoundFailure([super.message = '요청한 정보를 찾을 수 없어요.']);
}

/// 400/422 — 필드 인라인 오류로 매핑한다.
class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message, {this.fieldErrors = const {}});
  final Map<String, String> fieldErrors;
}

class ServerFailure extends AppFailure {
  const ServerFailure([super.message = '일시적인 오류가 발생했어요. 잠시 후 다시 시도해주세요.']);
}

/// 소셜 SDK 로그인 실패 (취소 제외 — 취소는 null로 표현한다). 설정 오류·네트워크 등.
class SocialSdkFailure extends AppFailure {
  const SocialSdkFailure([super.message = '로그인 중 문제가 생겼어요. 잠시 후 다시 시도해주세요.']);
}

/// API 명세가 아직 없어 실서버 연동이 구현되지 않은 경우.
class NotImplementedFailure extends AppFailure {
  const NotImplementedFailure(String feature) : super('$feature 기능은 아직 준비 중이에요.');
}

class UnknownFailure extends AppFailure {
  const UnknownFailure([super.message = '알 수 없는 오류가 발생했어요.']);
}

/// 임의의 오류를 사용자에게 보여줄 문장으로 바꾼다.
String failureMessage(Object error) =>
    error is AppFailure ? error.message : const UnknownFailure().message;
