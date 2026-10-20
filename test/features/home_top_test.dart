import 'package:apt/features/course/domain/course_models.dart';
import 'package:apt/features/extraction/domain/extraction_models.dart';
import 'package:apt/features/home/domain/home_top.dart';
import 'package:apt/features/place/domain/place.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 10, 20, 14);

CourseSummary _course(String id, DateTime? date) => CourseSummary(id: id, title: id, placeCount: 4, date: date);

RecentExtraction _saved(String id, int daysAgo) => RecentExtraction(
      place: Place(id: id, name: id, address: '', categoryKey: 'cafe', categoryLabel: '카페'),
      sourceUrl: '',
      extractedAt: _now.subtract(Duration(days: daysAgo)),
    );

HomeTop _resolve({
  List<CourseSummary> courses = const [],
  int saved = 0,
  List<RecentExtraction> recent = const [],
  DateTime? seenAt,
}) =>
    resolveHomeTop(courses: courses, savedPlaceCount: saved, recentSaves: recent, nudgeSeenAt: seenAt, now: _now);

void main() {
  test('① 저장 0곳 · 코스 0개 → 시작 안내', () {
    expect(_resolve(), isA<HomeTopStart>());
  });

  test('② 저장만 있고 제안을 닫은 적 없음 → 최근 저장 전부가 새 저장', () {
    final top = _resolve(saved: 3, recent: [_saved('a', 1), _saved('b', 5)]);
    expect(top, isA<HomeTopNudge>());
    expect((top as HomeTopNudge).newSaves.map((r) => r.place.id), ['a', 'b']);
  });

  test('② 제안을 닫은 뒤에 저장한 곳만 센다, 없으면 비어 있다', () {
    final recent = [_saved('a', 1), _saved('b', 5)];
    final some = _resolve(saved: 3, recent: recent, seenAt: _now.subtract(const Duration(days: 3))) as HomeTopNudge;
    expect(some.newSaves.map((r) => r.place.id), ['a']);
    final none = _resolve(saved: 3, recent: recent, seenAt: _now) as HomeTopNudge;
    expect(none.newSaves, isEmpty);
  });

  test('③ 가장 가까운 예정 코스, 나머지는 n개 더', () {
    final top = _resolve(courses: [
      _course('far', DateTime(2026, 11, 2)),
      _course('near', DateTime(2026, 10, 21)),
      _course('past', DateTime(2026, 10, 12)),
    ]) as HomeTopCourse;
    expect(top.course.id, 'near');
    expect(top.isToday, isFalse);
    expect(top.moreCount, 1);
  });

  test('④ 날짜가 오늘이면 오늘 코스', () {
    final top = _resolve(courses: [_course('today', DateTime(2026, 10, 20))]) as HomeTopCourse;
    expect(top.isToday, isTrue);
  });

  test('⑤ 지난 코스만 있으면 ②와 같다', () {
    expect(_resolve(courses: [_course('past', DateTime(2026, 10, 12))], saved: 2), isA<HomeTopNudge>());
  });

  test('날짜 없는 코스는 날짜 있는 코스 뒤에 온다', () {
    final top = _resolve(courses: [_course('undated', null), _course('dated', DateTime(2026, 10, 25))]) as HomeTopCourse;
    expect(top.course.id, 'dated');
    expect(top.moreCount, 1);
  });
}
