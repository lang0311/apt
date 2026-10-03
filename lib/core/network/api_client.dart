import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../error/app_failure.dart';
import '../storage/token_storage.dart';

/// HTTP 클라이언트. 실제 엔드포인트/응답 구조는 API 명세 수령 후 각 Api*Repository에서 사용한다.
class ApiClient {
  ApiClient(this.dio);
  final Dio dio;

  Future<T> run<T>(Future<T> Function(Dio dio) request) async {
    try {
      return await request(dio);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}

/// 공통 응답 처리 (docs/06_API_INTEGRATION.md §5)
AppFailure mapDioException(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const TimeoutFailure();
    case DioExceptionType.connectionError:
      return const NetworkFailure();
    default:
      break;
  }
  final status = e.response?.statusCode;
  // NEEDS BACKEND: 에러 바디 구조(메시지/필드 오류 키)를 명세에 맞춰 파싱한다.
  return switch (status) {
    401 => const UnauthorizedFailure(),
    403 => const ForbiddenFailure(),
    404 => const NotFoundFailure(),
    400 || 422 => const ValidationFailure('입력한 내용을 확인해주세요.'),
    final s? when s >= 500 => const ServerFailure(),
    _ => const UnknownFailure(),
  };
}

/// 토큰을 붙이고, 401이면 세션 만료 콜백을 호출한다.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokens, this._onSessionExpired);
  final TokenStorage _tokens;
  final void Function() _onSessionExpired;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _tokens.readAccessToken();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // NEEDS BACKEND: 토큰 갱신 엔드포인트/정책. 갱신 실패 시에만 세션 만료 처리.
      _onSessionExpired();
    }
    handler.next(err);
  }
}

/// 세션 만료 시 호출될 콜백. auth feature가 등록한다.
final sessionExpiredHandlerProvider = Provider<void Function()>((ref) => () {});

final apiClientProvider = Provider<ApiClient>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: Env.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    // 추출/AI 추천은 응답이 길 수 있어 별도 요청에서 늘린다.
    receiveTimeout: const Duration(seconds: 30),
  ));
  dio.interceptors.add(AuthInterceptor(
    ref.watch(tokenStorageProvider),
    () => ref.read(sessionExpiredHandlerProvider)(),
  ));
  return ApiClient(dio);
});
