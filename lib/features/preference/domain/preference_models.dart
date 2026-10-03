/// 취향 키워드 그룹 (서버 키워드 체계로 동적 렌더링 — 화면 시안의 항목은 예시)
class PreferenceGroup {
  const PreferenceGroup({required this.key, required this.label, required this.items, this.multiSelect = true});
  final String key;
  final String label;
  final List<PreferenceItem> items;
  final bool multiSelect;
}

class PreferenceItem {
  const PreferenceItem({required this.key, required this.label});
  final String key;
  final String label;
}

class MyPreferences {
  const MyPreferences({
    required this.selectedKeys,
    this.autoAnalysisSupported = false,
    this.autoAnalysisEnabled = false,
    this.analyzedLabels = const [],
    this.analysisBasisCount,
  });

  final Set<String> selectedKeys;

  /// 서버가 암묵적 취향 분석을 지원하는지. false면 자동 분석 카드를 숨긴다 (가정 A4).
  final bool autoAnalysisSupported;
  final bool autoAnalysisEnabled;
  final List<String> analyzedLabels;

  /// "저장한 N곳을 바탕으로"
  final int? analysisBasisCount;
}
