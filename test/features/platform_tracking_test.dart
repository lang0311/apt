import 'package:apt/core/error/app_failure.dart';
import 'package:apt/core/network/api_client.dart';
import 'package:apt/features/platform/data/platform_client.dart';
import 'package:apt/features/platform/data/platform_repositories.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordingClient extends PlatformClient {
  RecordingClient() : super(ApiClient(Dio()));
  final requests = <Json>[];
  bool failTracking = false;

  @override
  Future<Json> me() async => {};

  @override
  Future<String> token(String id) async => 'signed-map-token';

  @override
  Future<dynamic> post(String path, [Json? body]) async {
    if (failTracking) throw const NetworkFailure();
    requests.add({'path': path, 'body': body});
    return {'id': 'event'};
  }
}

void main() {
  test('server place details record an authenticated place-view interaction', () async {
    final client = RecordingClient();
    client.places['p1'] = {'id': 'p1', 'name': 'Museum', 'address': 'Seoul'};
    final detail = await PlatformPlaceRepository(client).fetchPlace('p1');
    expect(detail.place.name, 'Museum');
    expect(client.requests.single['path'], '/me/interactions');
    expect(client.requests.single['body'], {'token': 'signed-map-token', 'action': 'place_view'});
  });

  test('tracking failure does not block the loaded place details', () async {
    final client = RecordingClient()..failTracking = true;
    client.places['p1'] = {'id': 'p1', 'name': 'Museum', 'address': 'Seoul'};
    final detail = await PlatformPlaceRepository(client).fetchPlace('p1');
    expect(detail.place.name, 'Museum');
  });
}
