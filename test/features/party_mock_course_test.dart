import 'package:apt/dev/mock/party_mock_repositories.dart';
import 'package:apt/features/course/domain/course_draft.dart';
import 'package:apt/features/course/domain/course_models.dart';
import 'package:apt/features/course/domain/course_repository.dart';
import 'package:apt/features/party/domain/party_models.dart';
import 'package:apt/features/party/domain/party_repository.dart';
import 'package:apt/features/place/domain/place.dart';
import 'package:flutter_test/flutter_test.dart';

Place _p(String id) => Place(id: id, name: id, address: '', categoryKey: 'cafe', categoryLabel: '카페');

const _me = PartyMember(id: 'me', nickname: '랑', isMe: true);

/// 서버 흉내: 파티에는 나만 있다
class _FakeServerParties implements PartyRepository {
  final calls = <String>[];

  @override
  Future<Party> createParty() async {
    calls.add('create');
    return const Party(id: 'server-party', members: [_me]);
  }

  @override
  Future<List<Party>> fetchMyParties() async => [await fetchParty('server-party')];
  @override
  Future<Party> fetchParty(String partyId) async => Party(id: partyId, members: const [_me]);

  @override
  Future<InviteLink> createInviteLink(String partyId) async {
    calls.add('invite $partyId');
    return const InviteLink(url: 'server-link');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 서버 흉내: 받은 초안을 기록하고, 파티 코스는 인원 1명(나)으로 돌려준다
class _FakeServerCourses implements CourseRepository {
  final drafts = <CourseDraft>[];

  @override
  Future<Recommendation> recommend({
    required CourseDraft draft,
    List<CourseStop> currentStops = const [],
    void Function(RecommendationStage stage)? onStage,
  }) async {
    drafts.add(draft);
    return const Recommendation(stops: []);
  }

  @override
  Future<Course> createCourse({required CourseDraft draft, required List<CourseStop> stops}) async {
    drafts.add(draft);
    return Course(
      id: draft.name,
      title: draft.name,
      stops: const [],
      isParty: draft.companion == Companion.party,
      partyId: draft.partyId,
      canEdit: false,
    );
  }

  @override
  Future<List<CourseSummary>> fetchPartyCourses() async => const [
        CourseSummary(id: 'c1', title: '파티 코스', placeCount: 3, isParty: true),
      ];
  @override
  Future<List<CourseSummary>> fetchMyCourses() async => const [CourseSummary(id: 'c2', title: '혼자 코스', placeCount: 2)];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final partyDraft = CourseDraft(name: '파티 코스', places: [_p('a')], companion: Companion.party, partyId: 'server-party');

  test('파티 만들기 · 초대는 서버로 가고, 서버 파티원 뒤에 Mock 파티원만 덧붙는다', () async {
    final server = _FakeServerParties();
    final repo = MockMembersPartyRepository(server);

    final created = await repo.createParty();
    final link = await repo.createInviteLink(created.id);

    expect(server.calls, ['create', 'invite server-party']);
    expect(link.url, 'server-link');
    expect(created.id, 'server-party');
    expect([for (final m in created.members) m.nickname], ['랑', '민지', '랑이']);
    expect(created.members.where((m) => m.isMe), hasLength(1));
    expect((await repo.fetchMyParties()).single.members, hasLength(3));
    expect((await repo.fetchParty('server-party')).members, hasLength(3));
  });

  test('파티 코스 추천 · 저장은 서버 파티 id 그대로 서버로 간다', () async {
    final server = _FakeServerCourses();
    final repo = MockMembersCourseRepository(server);

    await repo.recommend(draft: partyDraft);
    final created = await repo.createCourse(draft: partyDraft, stops: const []);

    expect(server.drafts, hasLength(2));
    for (final sent in server.drafts) {
      expect(sent.companion, Companion.party);
      expect(sent.partyId, 'server-party');
    }
    expect(created.partyId, 'server-party');
    expect(created.canEdit, isFalse); // 서버 값 그대로
  });

  test('파티 코스 인원 수에만 Mock 파티원 수를 더한다', () async {
    final repo = MockMembersCourseRepository(_FakeServerCourses());

    expect((await repo.createCourse(draft: partyDraft, stops: const [])).memberCount, 3);
    expect((await repo.fetchPartyCourses()).single.memberCount, 3);
    expect((await repo.fetchMyCourses()).single.memberCount, 1);
  });
}
