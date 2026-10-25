import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env.dart';

/// Repository가 어디서 데이터를 가져오는지.
/// - [mock]: 앱 안의 Mock 데이터
/// - [api]: API 명세 기준 Api* 구현 (NEEDS BACKEND)
/// - [server]: 팀 Python 서버 (Platform* 구현)
enum DataSource { mock, api, server }

/// 실행 옵션으로 정해지고, 서버 모드에서는 로그인 방법에 따라 바뀐다 (07 D28).
/// 아이디 로그인 → [DataSource.server], 소셜 로그인 → [DataSource.mock] (서버가 소셜 로그인을 지원할 때까지).
class DataSourceController extends Notifier<DataSource> {
  static DataSource get initial =>
      Env.localBackend ? DataSource.server : (Env.useMock ? DataSource.mock : DataSource.api);

  @override
  DataSource build() => initial;

  /// 서버 모드에서 소셜로 로그인했을 때
  void useMockForSocial() {
    if (Env.localBackend) state = DataSource.mock;
  }

  /// 로그아웃 · 세션 만료 · 아이디 로그인 시작
  void reset() => state = initial;
}

final dataSourceProvider = NotifierProvider<DataSourceController, DataSource>(DataSourceController.new);
