class PartyMember {
  const PartyMember({required this.id, required this.nickname, this.avatarUrl, this.isMe = false});
  final String id;
  final String nickname;
  final String? avatarUrl;
  final bool isMe;

  String get initial => isMe ? '나' : (nickname.isEmpty ? '?' : String.fromCharCode(nickname.runes.first));
}

class Party {
  const Party({required this.id, required this.members, this.preferenceSummary = const []});
  final String id;
  final List<PartyMember> members;

  /// 파티원 취향 종합 키워드 (서버 집계)
  final List<String> preferenceSummary;
}

extension PartyMemberNames on List<PartyMember> {
  /// 한 줄을 넘지 않게: 나를 맨 앞에, 세 명까지 이름, 넘치면 "외 n명". 서버 파티 이름은 만든 사람 이름이라(07 D38) 파티원 이름으로 구분한다.
  String get crewNames {
    final sorted = [...where((m) => m.isMe), ...where((m) => !m.isMe)];
    final shown = [for (final m in sorted.take(3)) m.isMe ? '나' : m.nickname];
    return length > 3 ? '${shown.take(2).join(', ')} 외 ${length - 2}명' : shown.join(', ');
  }

  /// 나를 뺀 이름들 ("민지, 랑이"), 넘치면 "외 n명"
  String get otherNames {
    final names = [for (final m in this) if (!m.isMe) m.nickname];
    return names.length > 2 ? '${names.take(2).join(', ')} 외 ${names.length - 2}명' : names.join(', ');
  }
}

class InviteLink {
  const InviteLink({required this.url});
  final String url;
}

/// 초대 수락 화면 데이터
class Invitation {
  const Invitation({
    required this.token,
    required this.inviterName,
    required this.courseTitle,
    this.courseDate,
    required this.memberCount,
    this.previewPlaceNames = const [],
    this.previewImageUrl,
    this.selectedPlaceCount = 0,
  });

  final String token;
  final String inviterName;
  final String courseTitle;
  final DateTime? courseDate;
  final int memberCount;
  final List<String> previewPlaceNames;
  final String? previewImageUrl;
  final int selectedPlaceCount;
}

/// 초대 예외 (디자인 없음 → 공통 오류 상태로 표시)
enum InviteFailureKind {
  expired('초대가 만료됐어요', '초대한 친구에게 새 링크를 요청해주세요.'),
  alreadyJoined('이미 참여한 코스예요', '코스 목록의 모임/파티 코스에서 확인할 수 있어요.'),
  full('참여 인원이 가득 찼어요', '코스를 만든 친구에게 문의해주세요.');

  const InviteFailureKind(this.title, this.description);
  final String title;
  final String description;
}

class InviteFailure implements Exception {
  const InviteFailure(this.kind);
  final InviteFailureKind kind;

  @override
  String toString() => kind.title;
}
