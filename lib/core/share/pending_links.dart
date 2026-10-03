import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 로그인 전에 들어온 공유 URL / 초대 토큰을 보관했다가 로그인 후 이어서 처리한다.
/// (docs/02 §5.3 pendingShare, docs/04 §E)
class PendingLinks {
  const PendingLinks({this.shareUrl, this.inviteToken});
  final String? shareUrl;
  final String? inviteToken;
}

class PendingLinksController extends Notifier<PendingLinks> {
  @override
  PendingLinks build() => const PendingLinks();

  void setShare(String url) => state = PendingLinks(shareUrl: url, inviteToken: state.inviteToken);
  void setInvite(String token) => state = PendingLinks(shareUrl: state.shareUrl, inviteToken: token);
  void clearShare() => state = PendingLinks(inviteToken: state.inviteToken);
  void clearInvite() => state = PendingLinks(shareUrl: state.shareUrl);
}

final pendingLinksProvider = NotifierProvider<PendingLinksController, PendingLinks>(PendingLinksController.new);
