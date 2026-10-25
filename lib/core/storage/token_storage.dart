import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 인증 토큰 보안 저장소. 만료/갱신 정책은 API 명세 기준 (NEEDS BACKEND).
class TokenStorage {
  TokenStorage(this._storage);
  final FlutterSecureStorage _storage;

  static const _accessKey = 'auth.access';
  static const _refreshKey = 'auth.refresh';
  static const _sessionKey = 'auth.session';

  Future<String?> readAccessToken() => _storage.read(key: _accessKey);
  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  Future<void> save({required String accessToken, String? refreshToken}) async {
    await _storage.write(key: _accessKey, value: accessToken);
    if (refreshToken != null) await _storage.write(key: _refreshKey, value: refreshToken);
  }

  /// 서버 모드 세션 쿠키 `apt_session` 값. 앱(웹 제외)에서만 쓴다 — 브라우저는 쿠키를 직접 관리한다.
  Future<String?> readSessionCookie() => _storage.read(key: _sessionKey);
  Future<void> saveSessionCookie(String value) => _storage.write(key: _sessionKey, value: value);
  Future<void> clearSessionCookie() => _storage.delete(key: _sessionKey);

  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => TokenStorage(const FlutterSecureStorage()),
);
