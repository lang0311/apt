/// 홈 통계 (서버 aggregate)
class HomeStats {
  const HomeStats({
    required this.savedPlaceCount,
    required this.activeCourseCount,
    required this.recentExtractionCount,
    this.recentExtractionPeriodLabel,
  });

  final int savedPlaceCount;
  final int activeCourseCount;
  final int recentExtractionCount;

  /// 예: "이번 주" — 집계 기간 문구는 서버 정의를 따른다.
  final String? recentExtractionPeriodLabel;
}
