import 'package:apt/core/error/app_failure.dart';
import 'package:apt/core/network/api_client.dart';
import 'package:apt/features/party/domain/party_models.dart';
import 'package:apt/features/platform/data/platform_client.dart';
import 'package:apt/features/platform/data/platform_repositories.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// 18번: 팀 서버는 파티를 8명까지만 받는다(platform_store.py join, 9번째는 409)
void main() {
  PartyMember m(int i) => PartyMember(id: 'u$i', nickname: '사람$i', isMe: i == 0);

  test('8명이면 가득 찬 파티', () {
    expect(Party(id: 'p', members: [for (var i = 0; i < 7; i++) m(i)]).isFull, isFalse);
    expect(Party(id: 'p', members: [for (var i = 0; i < 8; i++) m(i)]).isFull, isTrue);
  });

  test('초대를 열 때 서버 인원이 8명이면 참여 버튼 전에 가득 참으로 막는다', () async {
    final repo = PlatformPartyRepository(_Fake(responses: {'/mobile/invites/code': {'name': '랑님의 파티', 'inviter': '랑', 'member_count': 8}}));
    await expectLater(
      repo.fetchInvitation('code'),
      throwsA(isA<InviteFailure>().having((f) => f.kind, 'kind', InviteFailureKind.full)),
    );
  });

  test('7명이면 그대로 초대를 보여 준다', () async {
    final repo = PlatformPartyRepository(_Fake(responses: {'/mobile/invites/code': {'name': '랑님의 파티', 'inviter': '랑', 'member_count': 7}}));
    expect((await repo.fetchInvitation('code')).memberCount, 7);
  });

  test('참여하는 사이 다른 사람이 들어와 서버가 409로 막으면 가득 참으로 바꾼다', () async {
    final repo = PlatformPartyRepository(_Fake(postError: const ValidationFailure('파티는 최대 8명까지 참여할 수 있습니다.')));
    await expectLater(
      repo.acceptInvitation('code', shareMyPreferences: true),
      throwsA(isA<InviteFailure>().having((f) => f.kind, 'kind', InviteFailureKind.full)),
    );
  });

  test('가득 참 안내 문구', () {
    expect(InviteFailureKind.full.title, '인원이 다 찼어요');
    expect(InviteFailureKind.full.description, '파티에는 8명까지 들어갈 수 있어요.');
  });
}

class _Fake extends PlatformClient {
  _Fake({this.responses = const {}, this.postError}) : super(ApiClient(Dio()));
  final Map<String, dynamic> responses;
  final AppFailure? postError;

  @override
  Future<dynamic> get(String path, [Map<String, dynamic>? query]) async => responses[path];

  @override
  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    if (postError != null) throw postError!;
    return {};
  }
}
