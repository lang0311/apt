import 'package:apt/features/course/domain/course_draft.dart';
import 'package:apt/features/place/domain/place.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Place _p(String id) => Place(id: id, name: id, address: '', categoryKey: 'cafe', categoryLabel: '카페');

void main() {
  group('CourseDraft', () {
    test('기본 정보가 모두 있어야 다음 단계로', () {
      const empty = CourseDraft();
      expect(empty.infoComplete, isFalse);
      final filled = empty.copyWith(name: '가을 산책', date: DateTime(2026, 10, 12), startTime: const TimeOfDay(hour: 11, minute: 0));
      expect(filled.infoComplete, isTrue);
      expect(filled.copyWith(name: '  ').infoComplete, isFalse);
    });

    test('분위기 토글', () {
      final d = const CourseDraft().toggleMood('walk').toggleMood('photo').toggleMood('walk');
      expect(d.moodKeys, {'photo'});
    });

    test('장소 추가는 중복 없이 뒤에 붙는다', () {
      final d = const CourseDraft().addPlaces([_p('a'), _p('b')]).addPlaces([_p('b'), _p('c')]);
      expect(d.places.map((p) => p.id), ['a', 'b', 'c']);
    });

    test('순서 변경 (ReorderableListView 규칙)', () {
      final d = const CourseDraft().addPlaces([_p('a'), _p('b'), _p('c')]);
      expect(d.reorder(0, 3).places.map((p) => p.id), ['b', 'c', 'a']);
      expect(d.reorder(2, 0).places.map((p) => p.id), ['c', 'a', 'b']);
    });

    test('삭제와 추천 제외', () {
      final d = const CourseDraft().addPlaces([_p('a'), _p('b')]).removePlace('a').reject('x');
      expect(d.places.map((p) => p.id), ['b']);
      expect(d.rejectedPlaceIds, {'x'});
    });

    test('파티 ID 해제', () {
      final d = const CourseDraft(partyId: 'p1').copyWith(clearPartyId: true);
      expect(d.partyId, isNull);
    });
  });
}
