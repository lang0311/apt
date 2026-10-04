import 'package:flutter/foundation.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../../config/env.dart';

/// 네이버 지도 SDK 초기화 상태. [AptMap]은 [ready]가 true일 때만 실제 지도를 띄운다.
///
/// 클라이언트 ID는 `--dart-define=NAVER_MAP_CLIENT_ID=...`로 주입한다 (커밋 금지).
/// NCP 콘솔 Maps > Application에 Dynamic Map + Android 패키지명/iOS Bundle ID 등록이 필요하다.
abstract final class NaverMapSdk {
  static final ready = ValueNotifier<bool>(false);

  /// `runApp` 전에 한 번 호출한다. 키가 없거나 초기화에 실패하면 미리보기 지도로 동작한다.
  static Future<void> init() async {
    if (Env.naverMapClientId.isEmpty) return;
    try {
      await FlutterNaverMap().init(
        clientId: Env.naverMapClientId,
        // 인증 실패(잘못된 키·패키지명 미등록·사용량 초과)는 비동기로 온다 → 미리보기로 되돌린다.
        onAuthFailed: (e) {
          debugPrint('[NaverMap] 인증 실패: $e');
          ready.value = false;
        },
      );
      ready.value = true;
    } catch (e) {
      debugPrint('[NaverMap] 초기화 실패: $e');
    }
  }
}
