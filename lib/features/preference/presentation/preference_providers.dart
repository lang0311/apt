import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/repositories.dart';
import '../domain/preference_models.dart';

final preferenceGroupsProvider = FutureProvider.autoDispose<List<PreferenceGroup>>(
  (ref) => ref.watch(preferenceRepositoryProvider).fetchGroups(),
);

final myPreferencesProvider = FutureProvider.autoDispose<MyPreferences>(
  (ref) => ref.watch(preferenceRepositoryProvider).fetchMine(),
);

/// 내가 선택한 취향의 표시 이름 (서버 키워드 체계 기준)
final myPreferenceLabelsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final groups = await ref.watch(preferenceGroupsProvider.future);
  final mine = await ref.watch(myPreferencesProvider.future);
  return [
    for (final g in groups)
      for (final i in g.items)
        if (mine.selectedKeys.contains(i.key)) i.label,
  ];
});
