import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 이 기기에서 받은 마지막 추천(서버 초안 코스 id)과 받은 시각, 홈 안내를 닫은 초안 (13번).
/// 서버는 코스를 만든 시각을 주지 않고 초안을 지우는 API도 없어 기기에만 둔다.
/// 새 의존성을 늘리지 않으려고 이미 쓰는 secure storage를 key-value로 쓴다 (홈 제안과 같은 방식).
/// 기기 저장소가 없거나(테스트) 실패해도 추천 · 저장은 그대로 되게 오류는 삼킨다.
class UnsavedRecommendationStorage {
  UnsavedRecommendationStorage([this._storage = const FlutterSecureStorage()]);
  final FlutterSecureStorage _storage;

  static String _key(String userId) => 'course.unsaved.$userId';

  Future<({String courseId, DateTime receivedAt})?> read(String userId) async {
    try {
      final raw = await _storage.read(key: _key(userId));
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final at = DateTime.tryParse(json['at'] as String? ?? '');
      if (at == null || json['dismissed'] == true) return null;
      return (courseId: json['id'] as String, receivedAt: at);
    } catch (_) {
      return null;
    }
  }

  Future<void> remember(String userId, String courseId, DateTime receivedAt) =>
      _write(userId, {'id': courseId, 'at': receivedAt.toIso8601String()});

  /// 홈 안내 닫기 — 같은 초안은 다시 띄우지 않는다. 새 추천을 받으면 [remember]가 덮어쓴다.
  Future<void> dismiss(String userId, String courseId) async {
    final current = await read(userId);
    if (current == null || current.courseId != courseId) return;
    await _write(userId, {'id': courseId, 'at': current.receivedAt.toIso8601String(), 'dismissed': true});
  }

  Future<void> clear(String userId) async {
    try {
      await _storage.delete(key: _key(userId));
    } catch (_) {}
  }

  Future<void> _write(String userId, Map<String, Object> value) async {
    try {
      await _storage.write(key: _key(userId), value: jsonEncode(value));
    } catch (_) {}
  }
}
