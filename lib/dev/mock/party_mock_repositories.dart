import '../../features/course/domain/course_draft.dart';
import '../../features/course/domain/course_models.dart';
import '../../features/course/domain/course_repository.dart';
import '../../features/party/domain/party_models.dart';
import '../../features/party/domain/party_repository.dart';

/// 서버 모드에서 **파티원만 Mock**으로 채울 때 쓴다 (`PARTY_MOCK=true`, 시연용, 07 D39).
/// 파티 만들기 · 목록 · 초대 · 수락, 파티 코스의 추천 · 저장 · 상세는 모두 팀 서버 API 그대로이고,
/// 서버가 준 파티원 뒤에 Mock 파티원([mockPartyMembers])만 덧붙여 보여 준다.
/// 서버 파티에는 실제로 들어온 사람만 있으므로 추천의 파티원 취향 반영도 실제 파티원 기준이다.
const mockPartyMembers = [
  PartyMember(id: 'mock-member-1', nickname: '민지'),
  PartyMember(id: 'mock-member-2', nickname: '랑이'),
];

class MockMembersPartyRepository implements PartyRepository {
  MockMembersPartyRepository(this.server);
  final PartyRepository server;

  Party _withMockMembers(Party party) => Party(
        id: party.id,
        members: [...party.members, ...mockPartyMembers],
        preferenceSummary: party.preferenceSummary,
        isOwner: party.isOwner,
      );

  @override
  Future<Party> createParty() async => _withMockMembers(await server.createParty());

  @override
  Future<List<Party>> fetchMyParties() async => [for (final p in await server.fetchMyParties()) _withMockMembers(p)];

  @override
  Future<Party> fetchParty(String partyId) async => _withMockMembers(await server.fetchParty(partyId));

  @override
  Future<InviteLink> createInviteLink(String partyId) => server.createInviteLink(partyId);

  @override
  Future<Invitation> fetchInvitation(String token) => server.fetchInvitation(token);

  @override
  Future<void> acceptInvitation(String token, {required bool shareMyPreferences}) =>
      server.acceptInvitation(token, shareMyPreferences: shareMyPreferences);

  @override
  Future<void> declineInvitation(String token) => server.declineInvitation(token);
}

/// 코스는 전부 서버에 맡기고, 파티 코스의 **인원 수**에만 Mock 파티원 수를 더한다
/// (파티 화면의 파티원 수와 코스 카드 · 상세의 인원 수가 어긋나지 않게).
class MockMembersCourseRepository implements CourseRepository {
  MockMembersCourseRepository(this.server);
  final CourseRepository server;

  CourseSummary _summary(CourseSummary c) =>
      c.isParty ? c.copyWith(memberCount: c.memberCount + mockPartyMembers.length) : c;

  Course _course(Course c) => c.isParty ? c.copyWith(memberCount: c.memberCount + mockPartyMembers.length) : c;

  Future<List<CourseSummary>> _summaries(Future<List<CourseSummary>> list) async => [for (final c in await list) _summary(c)];

  @override
  Future<List<CourseSummary>> fetchMyCourses() => _summaries(server.fetchMyCourses());
  @override
  Future<List<CourseSummary>> fetchPartyCourses() => _summaries(server.fetchPartyCourses());
  @override
  Future<List<CourseSummary>> fetchActiveCourses() => _summaries(server.fetchActiveCourses());
  @override
  Future<List<SuggestedCourse>> fetchSuggestedCourses() => server.fetchSuggestedCourses();
  @override
  Future<Course> fetchCourse(String courseId) async => _course(await server.fetchCourse(courseId));
  @override
  Future<List<MoodOption>> fetchMoodOptions() => server.fetchMoodOptions();

  @override
  Future<Recommendation> recommend({
    required CourseDraft draft,
    List<CourseStop> currentStops = const [],
    void Function(RecommendationStage stage)? onStage,
  }) => server.recommend(draft: draft, currentStops: currentStops, onStage: onStage);

  @override
  Future<void> cancelRecommendation() => server.cancelRecommendation();
  @override
  Future<Course> createCourse({required CourseDraft draft, required List<CourseStop> stops}) async =>
      _course(await server.createCourse(draft: draft, stops: stops));
  @override
  Future<String> courseLink(String courseId) => server.courseLink(courseId);
  @override
  Future<Course> updateCourseStops({required String courseId, required List<CourseStop> stops}) async =>
      _course(await server.updateCourseStops(courseId: courseId, stops: stops));
  @override
  Future<List<BlockedPlace>> fetchBlockedPlaces() => server.fetchBlockedPlaces();
  @override
  Future<void> blockPlace(String placeId) => server.blockPlace(placeId);
  @override
  Future<void> unblockPlace(String placeId) => server.unblockPlace(placeId);
}
