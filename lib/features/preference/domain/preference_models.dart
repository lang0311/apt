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
  const MyPreferences({required this.selectedKeys, this.autoAnalysisEnabled = false});

  final Set<String> selectedKeys;

  /// 자동 분석은 화면에 없는 기능이라 서버에서 받은 값을 그대로 다시 보낸다 (07 §3)
  final bool autoAnalysisEnabled;
}
