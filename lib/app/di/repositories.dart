import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/token_storage.dart';
import '../../dev/mock/mock_store.dart';
import '../../features/auth/data/auth_repositories.dart';
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
import '../../features/place/data/place_repositories.dart';
import '../../features/place/domain/place_repository.dart';
import '../../features/preference/data/preference_repositories.dart';
import '../../features/preference/domain/preference_repository.dart';
import '../../features/saved/data/api_saved_repository.dart';
import '../../features/saved/data/mock_saved_repository.dart';
import '../../features/saved/domain/saved_repository.dart';

/// Repository 주입. `--dart-define=USE_MOCK=false`면 Api* 구현을 사용한다.
/// API 명세 수령 후에는 Api* 클래스만 채우면 되고, 화면/Provider 코드는 바뀌지 않는다.

/// 키가 있는 공급자만 실제 SDK, 나머지는 Mock SDK. 서버 토큰 교환은 [authRepositoryProvider]가 결정한다.
final socialAuthProvider = Provider<SocialAuthProvider>(
  (ref) => SdkSocialAuthProvider(fallback: MockSocialAuthProvider()),
);

final authRepositoryProvider = Provider<AuthRepository>((ref) => Env.useMock
    ? MockAuthRepository(ref.watch(mockStoreProvider), ref.watch(socialAuthProvider))
    : ApiAuthRepository(ref.watch(apiClientProvider), ref.watch(tokenStorageProvider), ref.watch(socialAuthProvider)));

final savedRepositoryProvider = Provider<SavedRepository>((ref) =>
    Env.useMock ? MockSavedRepository(ref.watch(mockStoreProvider)) : ApiSavedRepository(ref.watch(apiClientProvider)));

final placeRepositoryProvider = Provider<PlaceRepository>((ref) =>
    Env.useMock ? MockPlaceRepository(ref.watch(mockStoreProvider)) : ApiPlaceRepository(ref.watch(apiClientProvider)));

final extractionRepositoryProvider = Provider<ExtractionRepository>((ref) => Env.useMock
    ? MockExtractionRepository(ref.watch(mockStoreProvider))
    : ApiExtractionRepository(ref.watch(apiClientProvider)));

final homeRepositoryProvider = Provider<HomeRepository>((ref) =>
    Env.useMock ? MockHomeRepository(ref.watch(mockStoreProvider)) : ApiHomeRepository(ref.watch(apiClientProvider)));

final courseRepositoryProvider = Provider<CourseRepository>((ref) =>
    Env.useMock ? MockCourseRepository(ref.watch(mockStoreProvider)) : ApiCourseRepository(ref.watch(apiClientProvider)));

final partyRepositoryProvider = Provider<PartyRepository>((ref) =>
    Env.useMock ? MockPartyRepository(ref.watch(mockStoreProvider)) : ApiPartyRepository(ref.watch(apiClientProvider)));

final preferenceRepositoryProvider = Provider<PreferenceRepository>((ref) => Env.useMock
    ? MockPreferenceRepository(ref.watch(mockStoreProvider))
    : ApiPreferenceRepository(ref.watch(apiClientProvider)));

final myRepositoryProvider = Provider<MyRepository>((ref) =>
    Env.useMock ? MockMyRepository(ref.watch(mockStoreProvider)) : ApiMyRepository(ref.watch(apiClientProvider)));
