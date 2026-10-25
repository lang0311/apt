import 'dart:convert';
import 'dart:typed_data';

import 'package:apt/core/network/api_client.dart';
import 'package:apt/core/storage/token_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// 보안 저장소 대신 메모리에 세션 쿠키를 둔다.
class _MemoryTokenStorage extends TokenStorage {
  _MemoryTokenStorage() : super(const FlutterSecureStorage());
  String? session;

  @override
  Future<String?> readSessionCookie() async => session;
  @override
  Future<void> saveSessionCookie(String value) async => session = value;
  @override
  Future<void> clearSessionCookie() async => session = null;
  @override
  Future<String?> readAccessToken() async => null;
}

/// 경로별로 정해 둔 응답을 돌려주고, 받은 요청 헤더를 기록한다.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.routes);
  final Map<String, (int, Map<String, List<String>>)> routes;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final (status, headers) = routes[options.path]!;
    return ResponseBody.fromString(
      jsonEncode({'ok': status == 200}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _MemoryTokenStorage storage;
  late _FakeAdapter adapter;
  late Dio dio;
  var expired = 0;

  setUp(() {
    storage = _MemoryTokenStorage();
    expired = 0;
    adapter = _FakeAdapter({
      '/auth/login': (200, {'set-cookie': ['apt_session=abc123; HttpOnly; Max-Age=604800; Path=/; SameSite=strict']}),
      '/me': (200, {}),
      '/auth/logout': (200, {'set-cookie': ['apt_session=""; expires=Thu, 01 Jan 1970 00:00:00 GMT; Max-Age=0; Path=/']}),
      '/expired': (401, {}),
    });
    dio = Dio(BaseOptions(baseUrl: 'http://server'))
      ..httpClientAdapter = adapter
      ..interceptors.add(AuthInterceptor(storage, () => expired++, cookieSession: true));
  });

  group('서버 모드 세션 쿠키', () {
    test('로그인 응답의 apt_session을 저장한다', () async {
      await dio.post<dynamic>('/auth/login');
      expect(storage.session, 'abc123');
    });

    test('저장한 쿠키를 다음 요청에 붙인다', () async {
      storage.session = 'abc123';
      await dio.get<dynamic>('/me');
      expect(adapter.requests.single.headers['Cookie'], 'apt_session=abc123');
    });

    test('로그아웃 응답(Max-Age=0)이면 지운다', () async {
      storage.session = 'abc123';
      await dio.post<dynamic>('/auth/logout');
      expect(storage.session, isNull);
    });

    test('401이면 지우고 세션 만료를 알린다', () async {
      storage.session = 'abc123';
      await expectLater(dio.get<dynamic>('/expired'), throwsA(isA<DioException>()));
      expect(storage.session, isNull);
      expect(expired, 1);
    });
  });
}
