import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/repositories.dart';
import '../domain/extraction_models.dart';

/// URL별 추출 결과. 화면 진입 시 분석을 자동 시작한다 (공유 진입 포함).
final extractionProvider = FutureProvider.autoDispose.family<ExtractionResult, String>(
  (ref, url) => ref.watch(extractionRepositoryProvider).extract(url),
);

/// 홈 "최근 추출한 장소"
final recentExtractionsProvider = FutureProvider.autoDispose<List<RecentExtraction>>(
  (ref) => ref.watch(extractionRepositoryProvider).fetchRecent(),
);
