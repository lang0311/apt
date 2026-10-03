import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/repositories.dart';
import '../domain/my_models.dart';

final myProfileProvider = FutureProvider.autoDispose<MyProfile>(
  (ref) => ref.watch(myRepositoryProvider).fetchProfile(),
);
