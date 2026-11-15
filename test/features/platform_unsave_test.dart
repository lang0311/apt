import 'dart:convert';
import 'dart:typed_data';

import 'package:apt/core/error/app_failure.dart';
import 'package:apt/core/network/api_client.dart';
import 'package:apt/features/platform/data/platform_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// 받은 요청을 기록하고 항상 {ok: true}로 답한다.
class _Recorder implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(jsonEncode({'ok': true}), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Recorder server;
  late PlatformClient client;

  setUp(() {
    server = _Recorder();
    client = PlatformClient(ApiClient(Dio()..httpClientAdapter = server));
  });

  const savedRecord = {
    'key': 'k-onion',
    'name': '어니언 성수',
    'address': '서울 성동구 성수동2가 277-135',
    'place_url': 'http://place.map.kakao.com/1',
    'selection_token': 'signed',
  };

  test('저장 해제는 DELETE /me/places/{key}로 가고, 저장 표시가 풀리고 토큰은 남는다', () async {
    expect(client.place(Map.of(savedRecord), saved: true).isSaved, isTrue);

    await client.unsave('k-onion');

    expect(server.requests.single.method, 'DELETE');
    expect(server.requests.single.path, '/me/places/k-onion');
    expect(client.place(Map.of(savedRecord)).isSaved, isFalse);
    expect(client.places['k-onion']!['selection_token'], 'signed'); // 되돌리기(다시 저장)에 쓴다
  });

  test('검색 결과에서 온 장소(id가 카카오 장소 id)는 같은 place_url의 저장 key로 지운다', () async {
    client.place(Map.of(savedRecord), saved: true);
    client.place({'id': '1', 'name': '어니언 성수', 'address': '서울 성동구', 'place_url': 'http://place.map.kakao.com/1'}, saved: true);

    await client.unsave('1');

    expect(server.requests.single.path, '/me/places/k-onion');
    expect(client.places['1']!['is_saved'], isFalse);
    expect(client.places['k-onion']!['is_saved'], isFalse);
  });

  test('job 번호를 받기 전에 누른 취소는 번호를 받자마자 서버에 보낸다', () async {
    await client.cancelRecommendation(); // 아직 번호가 없어 표시만 남는다
    expect(server.requests, isEmpty);

    await expectLater(client.poll('j1'), throwsA(isA<CancelledFailure>()));

    expect(server.requests.single.method, 'POST');
    expect(server.requests.single.path, '/jobs/j1/cancel');
    expect(client.activeJob, isNull);
  });
}
