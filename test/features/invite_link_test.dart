import 'package:apt/core/error/app_failure.dart';
import 'package:apt/core/network/api_client.dart';
import 'package:apt/features/party/domain/party_models.dart';
import 'package:apt/features/platform/data/platform_client.dart';
import 'package:apt/features/platform/data/platform_repositories.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// 17번: 서버 초대 링크는 `expires_in`(초) 뒤에 끝나고, 한 사람이 참여하면 바로 지워진다(platform_store.py invite · join)
void main() {
  test('초대 링크의 유효 시간을 서버 expires_in으로 읽는다', () async {
    final repo = PlatformPartyRepository(_Fake(postBody: {'code': 'abc', 'expires_in': 86400}));
    final link = await repo.createInviteLink('p');
    expect(link.url, endsWith('/invites/abc'));
    expect(link.expiresIn, const Duration(hours: 24));
  });

  test('이미 쓰였거나 시간이 지난 링크(서버 404)는 만료 화면으로', () async {
    final repo = PlatformPartyRepository(_Fake(getError: const NotFoundFailure()));
    await expectLater(
      repo.fetchInvitation('used'),
      throwsA(isA<InviteFailure>().having((f) => f.kind, 'kind', InviteFailureKind.expired)),
    );
  });

  test('참여를 누르는 사이 링크가 쓰였으면(서버 404) 만료로', () async {
    final repo = PlatformPartyRepository(_Fake(postError: const NotFoundFailure()));
    await expectLater(
      repo.acceptInvitation('used', shareMyPreferences: true),
      throwsA(isA<InviteFailure>().having((f) => f.kind, 'kind', InviteFailureKind.expired)),
    );
  });
}

class _Fake extends PlatformClient {
  _Fake({this.postBody = const {}, this.getError, this.postError}) : super(ApiClient(Dio()));
  final Map<String, dynamic> postBody;
  final AppFailure? getError;
  final AppFailure? postError;

  @override
  Future<dynamic> get(String path, [Map<String, dynamic>? query]) async => throw getError!;

  @override
  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    if (postError != null) throw postError!;
    return postBody;
  }
}
