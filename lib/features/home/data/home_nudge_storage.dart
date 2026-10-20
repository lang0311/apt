import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 홈 "최근 n곳을 저장했어요" 제안을 마지막으로 닫은(또는 코스를 만든) 시각.
/// 서버 없이 기기에만 둔다. 새 의존성을 늘리지 않으려고 이미 쓰는 secure storage를 key-value로 쓴다.
class HomeNudgeStorage {
  HomeNudgeStorage(this._storage);
  final FlutterSecureStorage _storage;

  static const _key = 'home.nudgeSeenAt';

  Future<DateTime?> read() async {
    final raw = await _storage.read(key: _key);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> write(DateTime? at) =>
      at == null ? _storage.delete(key: _key) : _storage.write(key: _key, value: at.toIso8601String());
}

final homeNudgeStorageProvider = Provider<HomeNudgeStorage>(
  (ref) => HomeNudgeStorage(const FlutterSecureStorage()),
);
