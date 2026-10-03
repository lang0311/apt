import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/repositories.dart';
import '../../place/domain/place.dart';
import '../domain/home_models.dart';

/// 홈 섹션은 각각 독립적으로 로딩/오류를 처리한다 (docs/05 #9).
final homeStatsProvider = FutureProvider.autoDispose<HomeStats>(
  (ref) => ref.watch(homeRepositoryProvider).fetchStats(),
);

final trendingPlacesProvider = FutureProvider.autoDispose<List<Place>>(
  (ref) => ref.watch(homeRepositoryProvider).fetchTrendingPlaces(),
);
