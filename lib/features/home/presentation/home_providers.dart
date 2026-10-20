import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/repositories.dart';
import '../../place/domain/place.dart';
import '../data/home_nudge_storage.dart';
import '../domain/home_models.dart';

/// 홈 섹션은 각각 독립적으로 로딩/오류를 처리한다 (docs/05 #9).
final homeStatsProvider = FutureProvider.autoDispose<HomeStats>(
  (ref) => ref.watch(homeRepositoryProvider).fetchStats(),
);

final trendingPlacesProvider = FutureProvider.autoDispose<List<Place>>(
  (ref) => ref.watch(homeRepositoryProvider).fetchTrendingPlaces(),
);

/// "최근 n곳을 저장했어요" 제안을 마지막으로 닫은(또는 코스를 만든) 시각
final homeNudgeSeenAtProvider = AsyncNotifierProvider<HomeNudgeController, DateTime?>(HomeNudgeController.new);

class HomeNudgeController extends AsyncNotifier<DateTime?> {
  @override
  Future<DateTime?> build() => ref.read(homeNudgeStorageProvider).read();

  /// 지금까지 저장한 곳은 본 것으로 친다. 되돌리기를 위해 직전 값을 돌려준다.
  Future<DateTime?> markSeen() async {
    final previous = state.value;
    await _set(DateTime.now());
    return previous;
  }

  Future<void> restore(DateTime? previous) => _set(previous);

  Future<void> _set(DateTime? at) async {
    state = AsyncData(at);
    await ref.read(homeNudgeStorageProvider).write(at);
  }
}
