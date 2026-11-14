import '../../../core/utils/formatters.dart';
import '../../course/domain/course_models.dart';
import '../../extraction/domain/extraction_models.dart';

/// 홈 맨 위 자리. 상황에 따라 하나만 보여 준다 (docs/05 #9, docs/07 D20).
sealed class HomeTop {
  const HomeTop();
}

/// ① 저장 0곳 · 코스 0개 → 시작 안내
class HomeTopStart extends HomeTop {
  const HomeTopStart();
}

/// ② 예정 코스 없음 → 새로 저장한 곳이 있으면 제안 카드, 없으면 자리 없음
class HomeTopNudge extends HomeTop {
  const HomeTopNudge(this.newSaves);

  /// 마지막으로 제안을 닫은(또는 코스를 만든) 뒤 저장한 곳. 비어 있으면 아무것도 안 보여 준다.
  final List<RecentExtraction> newSaves;
}

/// ③ 다가오는 코스 / ④ 오늘 코스 (같은 카드, [isToday]로만 표시가 다르다)
class HomeTopCourse extends HomeTop {
  const HomeTopCourse({required this.course, required this.isToday, required this.moreCount});
  final CourseSummary course;
  final bool isToday;

  /// 이 코스 말고 남은 예정 코스 수 ("n개 더 보기")
  final int moreCount;
}

/// 날짜를 정하지 않은 다가오는 코스 (맨 위 큰 카드로 쓰지 않고 지역별로 시작하기 아래 한 줄로, 07 D58)
List<CourseSummary> undatedCourses(List<CourseSummary> courses) => [for (final c in courses) if (c.date == null) c];

/// 코스는 당일 일정 기준이다. 지난 코스는 맨 위 자리에 쓰지 않는다(⑤ → ②와 같음).
/// 맨 위 큰 카드는 날짜가 있는 다가오는 코스만 쓴다. 날짜 없는 코스는 그 카드의 "n개 더"에 함께 센다(07 D58).
HomeTop resolveHomeTop({
  required List<CourseSummary> courses,
  required int savedPlaceCount,
  required List<RecentExtraction> recentSaves,
  required DateTime? nudgeSeenAt,
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final dated = [
    for (final c in courses)
      if (c.date != null && daysUntil(c.date!, now: current) >= 0) c,
  ]..sort((a, b) => a.date!.compareTo(b.date!));
  final undated = undatedCourses(courses);

  if (dated.isNotEmpty) {
    final first = dated.first;
    return HomeTopCourse(
      course: first,
      isToday: daysUntil(first.date!, now: current) == 0,
      moreCount: dated.length - 1 + undated.length,
    );
  }
  if (savedPlaceCount == 0 && recentSaves.isEmpty) return const HomeTopStart();
  return HomeTopNudge([
    for (final r in recentSaves)
      if (nudgeSeenAt == null || r.extractedAt.isAfter(nudgeSeenAt)) r,
  ]);
}
