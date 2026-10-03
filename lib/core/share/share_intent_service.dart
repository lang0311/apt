import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 다른 앱(인스타그램 등)의 "공유"로 들어온 텍스트를 받는다.
///
/// - Android: `ACTION_SEND`(text/plain) — MainActivity.kt가 채널로 전달 (콜드/웜 스타트 모두)
/// - iOS: Share Extension 타깃 + App Group 필요 (아직 미구성 — Xcode 작업, 실기기 검증 필요)
///
/// 외부 패키지 대신 플랫폼 채널을 직접 쓴다. 수신 패키지를 채택하면 이 클래스 내부만 바꾼다.
class ShareIntentService {
  ShareIntentService();

  static const _method = MethodChannel('apt/share');
  static const _events = EventChannel('apt/share/events');

  /// 앱이 공유로 실행된 경우 그 텍스트 (한 번만 반환)
  Future<String?> initialText() async {
    if (!_supported) return null;
    try {
      return await _method.invokeMethod<String>('getInitialText');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// 실행 중에 들어오는 공유
  Stream<String> get onText {
    if (!_supported) return const Stream.empty();
    return _events.receiveBroadcastStream().where((e) => e is String).cast<String>().handleError((_) {});
  }

  bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}

final shareIntentServiceProvider = Provider<ShareIntentService>((ref) => ShareIntentService());
