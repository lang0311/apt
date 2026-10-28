class MyProfile {
  const MyProfile({
    required this.nickname,
    this.handle,
    this.profileImageUrl,
    required this.savedPlaceCount,
    required this.createdCourseCount,
    required this.joinedCourseCount,
  });

  final String nickname;
  final String? handle;
  final String? profileImageUrl;

  /// 통계 (서버 aggregate, 프리뷰 순서: 저장한 장소 · 만든 코스 · 참여한 코스)
  final int savedPlaceCount;
  final int createdCourseCount;
  final int joinedCourseCount;
}

abstract interface class MyRepository {
  Future<MyProfile> fetchProfile();
}
