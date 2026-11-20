import 'dart:convert';
import 'dart:typed_data';

import 'package:apt/core/network/api_client.dart';
import 'package:apt/features/course/domain/course_draft.dart';
import 'package:apt/features/platform/data/platform_client.dart';
import 'package:apt/features/platform/data/platform_repositories.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';

/// 요청을 기록한다. 진행 중 job은 없다고 답하고, 새 추천 요청(POST /jobs)은 본문만 남기고 실패시킨다.
class _Recorder implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final listJobs = options.method == 'GET' && options.path == '/jobs';
    return ResponseBody.fromString(listJobs ? '[]' : jsonEncode({'detail': 'stop'}), listJobs ? 200 : 500, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Recorder server;
  late PlatformClient client;
  late PlatformCourseRepository repository;

  setUp(() {
    server = _Recorder();
    client = PlatformClient(ApiClient(Dio()..httpClientAdapter = server));
    repository = PlatformCourseRepository(client);
  });

  Map<String, dynamic> jobBody() {
    final post = server.requests.singleWhere((r) => r.method == 'POST' && r.path == '/jobs');
    return Map<String, dynamic>.from(post.data as Map);
  }

  final place = {
    'key': 'k-onion',
    'name': '어니언 성수',
    'address': '서울 성동구 성수동2가 277-135',
    'selection_token': 'signed',
  };

  test('새 추천 요청에 방문 날짜와 출발 시간을 서버 형식으로 보낸다', () async {
    final draft = CourseDraft(
      date: DateTime(2026, 11, 21),
      startTime: const TimeOfDay(hour: 9, minute: 5),
      places: [client.place(Map.of(place), saved: true)],
    );

    await expectLater(repository.recommend(draft: draft), throwsA(anything));

    expect(jobBody()['visit_date'], '2026-11-21');
    expect(jobBody()['start_time'], '09:05');
  });

  test('날짜 · 시간이 없으면 null로 보내 서버 기본값(12:00)을 쓴다', () async {
    final draft = CourseDraft(places: [client.place(Map.of(place), saved: true)]);

    await expectLater(repository.recommend(draft: draft), throwsA(anything));

    expect(jobBody()['visit_date'], isNull);
    expect(jobBody()['start_time'], isNull);
  });
}
