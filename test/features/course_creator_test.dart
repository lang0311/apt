import 'package:apt/core/network/api_client.dart';
import 'package:apt/features/party/domain/party_models.dart';
import 'package:apt/features/platform/data/platform_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 19번: 코스 응답의 `owner`(만든 사람 id)를 파티원 이름으로
void main() {
  const members = [
    PartyMember(id: 'u0', nickname: '랑', isMe: true),
    PartyMember(id: 'u1', nickname: '지민'),
  ];

  test('코스 응답의 owner를 읽는다', () {
    final c = PlatformClient(ApiClient(Dio()));
    final course = c.course({'id': 'c', 'status': 'draft', 'party_id': 'p', 'owner': 'u1', 'itinerary': []});
    expect(course.ownerId, 'u1');
  });

  test('출발 시간이 이상한 값이어도 코스는 읽고 출발 시간만 비운다', () {
    final c = PlatformClient(ApiClient(Dio()));
    for (final bad in ['11', '', '오전 11시', 'aa:bb']) {
      final course = c.course({'id': 'c', 'status': 'draft', 'start_time': bad, 'itinerary': []});
      expect(course.startTime, isNull, reason: bad);
    }
    expect(c.course({'id': 'c', 'status': 'draft', 'start_time': '11:30:00', 'itinerary': []}).startTime, const TimeOfDay(hour: 11, minute: 30));
  });

  test('다른 파티원이 만든 코스면 "지민님이 만든 코스"', () {
    expect(members.creatorLine('u1'), '지민님이 만든 코스');
  });

  test('내가 만들었거나 모르는 사람이거나 값이 없으면 줄 없음', () {
    expect(members.creatorLine('u0'), isNull);
    expect(members.creatorLine('nobody'), isNull);
    expect(members.creatorLine(null), isNull);
  });
}
