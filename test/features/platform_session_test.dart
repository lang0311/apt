import 'dart:convert';
import 'dart:typed_data';

import 'package:apt/core/network/api_client.dart';
import 'package:apt/features/platform/data/platform_client.dart';
import 'package:apt/features/platform/data/platform_repositories.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// 어떤 요청에도 {ok: true}로 답한다.
class _OkServer implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    return ResponseBody.fromString(jsonEncode({'ok': true}), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('로그아웃하면 장소 · 코스 · 파티 캐시와 로그인한 사람을 모두 비운다', () async {
    final client = PlatformClient(ApiClient(Dio()..httpClientAdapter = _OkServer()));
    client.places['p'] = {};
    client.courses['c'] = {};
    client.partySizes['party'] = 3;
    client.partyOwners['party'] = 'u1';
    client.lastCourseId = 'c';
    client.currentUserId = 'u1';

    await PlatformAuthRepository(client).signOut();

    expect(client.places, isEmpty);
    expect(client.courses, isEmpty);
    expect(client.partySizes, isEmpty);
    expect(client.partyOwners, isEmpty);
    expect(client.lastCourseId, isNull);
    expect(client.currentUserId, isNull);
  });
}
