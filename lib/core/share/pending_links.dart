import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 로그인 전에 들어온 공유 URL / 초대 토큰 / 코스 링크를 보관했다가 로그인 후 이어서 처리한다.
/// (docs/02 §5.3 pendingShare, docs/04 §E)
class PendingLinks {
  const PendingLinks({this.shareUrl, this.inviteToken, this.courseId});
  final String? shareUrl;
  final String? inviteToken;

  /// 파티원이 받은 코스 링크
  final String? courseId;
}

class PendingLinksController extends Notifier<PendingLinks> {
  @override
  PendingLinks build() => const PendingLinks();

  void setShare(String url) => state = PendingLinks(shareUrl: url, inviteToken: state.inviteToken, courseId: state.courseId);
  void setInvite(String token) => state = PendingLinks(shareUrl: state.shareUrl, inviteToken: token, courseId: state.courseId);
  void setCourse(String id) => state = PendingLinks(shareUrl: state.shareUrl, inviteToken: state.inviteToken, courseId: id);
  void clearShare() => state = PendingLinks(inviteToken: state.inviteToken, courseId: state.courseId);
  void clearInvite() => state = PendingLinks(shareUrl: state.shareUrl, courseId: state.courseId);
  void clearCourse() => state = PendingLinks(shareUrl: state.shareUrl, inviteToken: state.inviteToken);
}

final pendingLinksProvider = NotifierProvider<PendingLinksController, PendingLinks>(PendingLinksController.new);
