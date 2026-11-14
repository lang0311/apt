import 'package:apt/features/place/domain/place.dart';
import 'package:apt/features/platform/data/platform_repositories.dart';
import 'package:flutter_test/flutter_test.dart';

Place _p(String id, String address) =>
    Place(id: id, name: id, address: address, categoryKey: 'food', categoryLabel: '음식');

void main() {
  test('고른 곳이 가장 많은 지역을 보낸다 (순서와 무관)', () {
    final places = [
      _p('a', '경기 김포시 고촌읍 1'),
      _p('b', '서울 마포구 연남동 2'),
      _p('c', '서울 마포구 서교동 3'),
    ];
    expect(courseArea(places), '서울 마포구');
  });

  test('같은 수면 먼저 고른 지역', () {
    expect(courseArea([_p('a', '경기 김포시 1'), _p('b', '서울 강서구 2')]), '경기 김포시');
  });

  test('주소가 빈 곳은 세지 않는다', () {
    expect(courseArea([_p('a', ''), _p('b', '  '), _p('c', '경기 김포시 1')]), '경기 김포시');
  });

  test('주소가 하나도 없으면 기본값', () {
    expect(courseArea([_p('a', '')]), '서울 마포구');
  });
}
