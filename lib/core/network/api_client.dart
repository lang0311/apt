import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../error/app_failure.dart';
import '../storage/token_storage.dart';
import 'browser_credentials_stub.dart' if (dart.library.js_interop) 'browser_credentials_web.dart';

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
  // 팀 서버는 입력 오류를 {"detail": "메시지"}로 준다. 화면 말투로 바꿀 곳은 각 Repository가 따로 처리한다.
  final body = e.response?.data;
  if (status case 400 || 409 || 422 || 429 when body is Map && body['detail'] is String) {
    return ValidationFailure(body['detail'] as String);
  }
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
/// 서버 모드에서는 Bearer 토큰 대신 세션 쿠키 `apt_session`을 직접 저장하고 붙인다 (브라우저는 알아서 처리).
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokens, this._onSessionExpired, {this.cookieSession = false});
  final TokenStorage _tokens;
  final void Function() _onSessionExpired;

  /// 서버 모드 + 앱(웹 아님)
  final bool cookieSession;

  static const _cookieName = 'apt_session';

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (cookieSession) {
      final session = await _tokens.readSessionCookie();
      if (session != null) options.headers['Cookie'] = '$_cookieName=$session';
    } else if (!Env.localBackend) {
      final token = await _tokens.readAccessToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  /// 로그인·가입 응답의 `Set-Cookie: apt_session=…`을 저장한다. 로그아웃은 빈 값(Max-Age=0)으로 온다.
  @override
  Future<void> onResponse(Response response, ResponseInterceptorHandler handler) async {
    if (cookieSession) {
      for (final header in response.headers['set-cookie'] ?? const <String>[]) {
        if (!header.startsWith('$_cookieName=')) continue;
        final value = header.split(';').first.substring(_cookieName.length + 1).replaceAll('"', '');
        if (value.isEmpty || header.toLowerCase().contains('max-age=0')) {
          await _tokens.clearSessionCookie();
        } else {
          await _tokens.saveSessionCookie(value);
        }
      }
    }
    handler.next(response);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      if (cookieSession) await _tokens.clearSessionCookie();
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
    // 팀 서버는 POST/PATCH/PUT/DELETE에 이 헤더가 없으면 403 (CSRF 방지)
    headers: Env.localBackend ? {'X-APT-Request': '1'} : null,
  ));
  if (Env.localBackend) configureCredentials(dio);
  dio.interceptors.add(AuthInterceptor(
    ref.watch(tokenStorageProvider),
    () => ref.read(sessionExpiredHandlerProvider)(),
    cookieSession: Env.localBackend && !kIsWeb,
  ));
  return ApiClient(dio);
});
