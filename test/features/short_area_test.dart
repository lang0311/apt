import 'package:apt/core/network/api_client.dart';
import 'package:apt/features/place/domain/place.dart';
import 'package:apt/features/platform/data/platform_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// 목록 · 카드의 짧은 동네 이름: 번지 · 건물 번호('416', '161')를 쓰지 않는다
void main() {
  test('동 · 읍 · 면 · 리 · 가가 있으면 그것, 없으면 구 · 군 · 시', () {
    // 2026-11-13 test 계정의 실제 저장 장소 주소
    expect(shortAreaOf('서울 강서구 화곡로 416'), '강서구');
    expect(shortAreaOf('서울 종로구 사직로 161'), '종로구');
    expect(shortAreaOf('경기 김포시 김포한강2로24번길 134-6'), '김포시');
    expect(shortAreaOf('서울 마포구 상수동 325-2'), '상수동');
    expect(shortAreaOf('서울 강서구 화곡동 산 60-1'), '화곡동');
    expect(shortAreaOf('서울 강서구 마곡동 760-2'), '마곡동');
    // 그 밖의 꼴
    expect(shortAreaOf('서울 성동구 성수동'), '성수동');
    expect(shortAreaOf('서울 중구 을지로3가 1'), '을지로3가');
    expect(shortAreaOf('강릉시 주문진읍'), '주문진읍');
    expect(shortAreaOf('경기 가평군 상면'), '상면');
    expect(shortAreaOf('서울 마포구 토정로 56'), '마포구');
    expect(shortAreaOf(''), '');
  });

  test('서버 장소는 지번 주소로 동네를 뽑고, 주소 줄은 도로명을 쓴다', () {
    final c = PlatformClient(ApiClient(Dio()));
    final place = c.place({
      'key': 'k1',
      'name': '금복식당',
      'road_address': '서울 마포구 와우산로 35',
      'address': '서울 마포구 상수동 325-2',
      'category': '음식점 > 일식',
    });
    expect(place.address, '서울 마포구 와우산로 35');
    expect(place.shortArea, '상수동');

    // 지번 주소가 없으면 도로명 주소로
    final roadOnly = c.place({'key': 'k2', 'name': '탕반가', 'road_address': '서울 강서구 화곡로 416', 'category': '음식점 > 한식'});
    expect(roadOnly.shortArea, '강서구');
  });
}
