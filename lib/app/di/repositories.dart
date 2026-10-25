import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/token_storage.dart';
import '../../dev/mock/mock_store.dart';
import '../../features/auth/data/auth_repositories.dart';
import '../../features/auth/data/server_mode_auth_repository.dart';
import '../../features/auth/data/social_auth_sdk.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../../features/course/data/course_repositories.dart';
import '../../features/course/domain/course_repository.dart';
import '../../features/extraction/data/extraction_repositories.dart';
import '../../features/extraction/domain/extraction_repository.dart';
import '../../features/home/data/home_repositories.dart';
import '../../features/home/domain/home_repository.dart';
import '../../features/my/data/my_repositories.dart';
import '../../features/my/domain/my_models.dart';
import '../../features/party/data/party_repositories.dart';
import '../../features/party/domain/party_repository.dart';
import '../../features/platform/data/platform_client.dart';
import '../../features/platform/data/platform_repositories.dart';
import '../../features/place/data/place_repositories.dart';
import '../../features/place/data/place_search_repositories.dart';
import '../../features/place/domain/place_repository.dart';
import '../../features/place/domain/place_search_repository.dart';
import '../../features/preference/data/preference_repositories.dart';
import '../../features/preference/domain/preference_repository.dart';
import '../../features/saved/data/api_saved_repository.dart';
import '../../features/saved/data/mock_saved_repository.dart';
import '../../features/saved/domain/saved_repository.dart';
import 'data_source.dart';

/// Repository 주입. 어떤 구현을 쓸지는 [dataSourceProvider]가 정한다.
/// - Mock: `USE_MOCK=true`(기본) — 앱 안의 Mock 데이터
/// - Api: `USE_MOCK=false` — API 명세 수령 후 Api* 클래스만 채우면 되고, 화면/Provider 코드는 바뀌지 않는다
/// - 서버: `APT_BACKEND=true` — 팀 Python 서버(Platform*). 서버에 없는 기능(추출 등)은 Mock으로 대신하지 않고 준비 중으로 둔다.
///   소셜로 로그인하면 Mock으로 바뀐다 (07 D28).

/// 키가 있는 공급자만 실제 SDK, 나머지는 Mock SDK. 서버 토큰 교환은 [authRepositoryProvider]가 결정한다.
final socialAuthProvider = Provider<SocialAuthProvider>(
  (ref) => SdkSocialAuthProvider(fallback: MockSocialAuthProvider()),
);

/// 서버 모드에서는 로그인 방법과 상관없이 한 구현(아이디는 서버, 소셜은 Mock)을 쓴다.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final mock = MockAuthRepository(ref.watch(mockStoreProvider), ref.watch(socialAuthProvider));
  if (Env.localBackend) {
    return ServerModeAuthRepository(
      server: PlatformAuthRepository(ref.watch(platformClientProvider)),
      mock: mock,
      isSocialSession: () => ref.read(dataSourceProvider) == DataSource.mock,
    );
  }
  return Env.useMock
      ? mock
      : ApiAuthRepository(ref.watch(apiClientProvider), ref.watch(tokenStorageProvider), ref.watch(socialAuthProvider));
});

final savedRepositoryProvider = Provider<SavedRepository>((ref) => switch (ref.watch(dataSourceProvider)) {
      DataSource.mock => MockSavedRepository(ref.watch(mockStoreProvider)),
      DataSource.api => ApiSavedRepository(ref.watch(apiClientProvider)),
      DataSource.server => PlatformSavedRepository(ref.watch(platformClientProvider)),
    });

final placeRepositoryProvider = Provider<PlaceRepository>((ref) => switch (ref.watch(dataSourceProvider)) {
      DataSource.mock => MockPlaceRepository(ref.watch(mockStoreProvider)),
      DataSource.api => ApiPlaceRepository(ref.watch(apiClientProvider)),
      DataSource.server => PlatformPlaceRepository(ref.watch(platformClientProvider)),
    });

/// 지도에서 검색하기 (07 D32). 서버 모드는 팀 서버의 카카오 지도 검색.
final placeSearchRepositoryProvider = Provider<PlaceSearchRepository>((ref) => switch (ref.watch(dataSourceProvider)) {
      DataSource.mock => MockPlaceSearchRepository(ref.watch(mockStoreProvider)),
      DataSource.api => ApiPlaceSearchRepository(ref.watch(apiClientProvider)),
      DataSource.server => PlatformPlaceSearchRepository(ref.watch(platformClientProvider)),
    });

/// 팀 서버에 추출 기능이 없다 — 서버 모드는 추출 준비 중, 최근 기록은 저장 장소의 저장 시각으로 대신한다. NEEDS BACKEND
final extractionRepositoryProvider = Provider<ExtractionRepository>((ref) => switch (ref.watch(dataSourceProvider)) {
      DataSource.mock => MockExtractionRepository(ref.watch(mockStoreProvider)),
      DataSource.api => ApiExtractionRepository(ref.watch(apiClientProvider)),
      DataSource.server => PlatformExtractionRepository(ref.watch(platformClientProvider)),
    });

final homeRepositoryProvider = Provider<HomeRepository>((ref) => switch (ref.watch(dataSourceProvider)) {
      DataSource.mock => MockHomeRepository(ref.watch(mockStoreProvider)),
      DataSource.api => ApiHomeRepository(ref.watch(apiClientProvider)),
      DataSource.server => PlatformHomeRepository(ref.watch(platformClientProvider)),
    });

final courseRepositoryProvider = Provider<CourseRepository>((ref) => switch (ref.watch(dataSourceProvider)) {
      DataSource.mock => MockCourseRepository(ref.watch(mockStoreProvider)),
      DataSource.api => ApiCourseRepository(ref.watch(apiClientProvider)),
      DataSource.server => PlatformCourseRepository(ref.watch(platformClientProvider)),
    });

final partyRepositoryProvider = Provider<PartyRepository>((ref) => switch (ref.watch(dataSourceProvider)) {
      DataSource.mock => MockPartyRepository(ref.watch(mockStoreProvider)),
      DataSource.api => ApiPartyRepository(ref.watch(apiClientProvider)),
      DataSource.server => PlatformPartyRepository(ref.watch(platformClientProvider)),
    });

final preferenceRepositoryProvider = Provider<PreferenceRepository>((ref) => switch (ref.watch(dataSourceProvider)) {
      DataSource.mock => MockPreferenceRepository(ref.watch(mockStoreProvider)),
      DataSource.api => ApiPreferenceRepository(ref.watch(apiClientProvider)),
      DataSource.server => PlatformPreferenceRepository(ref.watch(platformClientProvider)),
    });

final myRepositoryProvider = Provider<MyRepository>((ref) => switch (ref.watch(dataSourceProvider)) {
      DataSource.mock => MockMyRepository(ref.watch(mockStoreProvider)),
      DataSource.api => ApiMyRepository(ref.watch(apiClientProvider)),
      DataSource.server => PlatformMyRepository(ref.watch(platformClientProvider)),
    });
