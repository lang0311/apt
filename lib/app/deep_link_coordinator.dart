import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/share/pending_links.dart';
import '../core/share/share_intent_service.dart';
import '../core/utils/instagram_url.dart';
import '../features/auth/presentation/auth_controller.dart';
import 'router.dart';
import 'routes.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// 외부 진입(공유 수신, 초대 링크)을 받아 로그인 상태에 맞춰 이어서 처리한다.
/// - 로그인 상태: 링크 입력을 건너뛰고 결과 화면에서 분석 자동 시작
/// - 비로그인/가입 중: pending으로 보관 → 홈 진입 직후 재개 (docs/02 §5.2–5.3)
class DeepLinkCoordinator extends ConsumerStatefulWidget {
  const DeepLinkCoordinator({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<DeepLinkCoordinator> createState() => _DeepLinkCoordinatorState();
}

class _DeepLinkCoordinatorState extends ConsumerState<DeepLinkCoordinator> {
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    final service = ref.read(shareIntentServiceProvider);
    service.initialText().then((t) {
      if (t != null) _onShared(t);
    });
    _sub = service.onText.listen(_onShared);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onShared(String text) {
    final url = InstagramUrl.extract(text);
    if (url == null) {
      _toast('인스타그램 게시물 링크만 장소를 찾을 수 있어요.');
      return;
    }
    ref.read(pendingLinksProvider.notifier).setShare(url);
    _tryResume();
  }

  void _tryResume() {
    final auth = ref.read(authControllerProvider);
    if (auth.status != AuthStatus.authenticated || auth.justSignedUp) return;
    final pending = ref.read(pendingLinksProvider);
    final router = ref.read(routerProvider);

    if (pending.inviteToken case final token?) {
      ref.read(pendingLinksProvider.notifier).clearInvite();
      router.push(AppRoutes.invite(token));
      return;
    }
    if (pending.shareUrl case final url?) {
      ref.read(pendingLinksProvider.notifier).clearShare();
      router.go(AppRoutes.extractResult(url, fromShare: true));
      _toast('공유한 게시물에서 장소를 찾고 있어요.');
    }
  }

  void _toast(String message) {
    scaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (_, _) => WidgetsBinding.instance.addPostFrameCallback((_) => _tryResume()));
    return widget.child;
  }
}
