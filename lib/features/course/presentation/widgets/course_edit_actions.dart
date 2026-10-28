import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/overlays.dart';
import '../../domain/course_models.dart';
import '../pages/add_places_page.dart';
import '../recommendation_controller.dart';
import 'course_stop_sheets.dart';

// 4단계 결과·편집과 저장한 코스 편집이 같이 쓰는 동작. 모든 빼기는 스낵바 "되돌리기"를 단다.

RecommendationController _rec(WidgetRef ref) => ref.read(recommendationProvider.notifier);

void _undoSnack(BuildContext context, WidgetRef ref, String message) =>
    showAppSnackBar(context, message, actionLabel: '되돌리기', onAction: () => _rec(ref).undo());

/// 이 코스에서 빼기 (이번만)
void removeStopWithUndo(BuildContext context, WidgetRef ref, CourseStop stop) {
  _rec(ref).removeStop(stop);
  _undoSnack(context, ref, '${withObjectParticle(stop.place.name)} 이번 코스에서 뺐어요');
}

/// 앞으로 추천하지 않기 (계정 단위 차단, AI 장소만)
Future<void> blockStopWithUndo(BuildContext context, WidgetRef ref, CourseStop stop) async {
  try {
    await _rec(ref).blockStop(stop);
    if (context.mounted) _undoSnack(context, ref, '${withTopicParticle(stop.place.name)} 앞으로 추천하지 않아요');
  } catch (e) {
    if (context.mounted) showAppSnackBar(context, failureMessage(e));
  }
}

/// 다시 추천 — 바뀐 자리 수를 알리고 되돌릴 수 있게 한다
Future<void> recommendAgainWithUndo(BuildContext context, WidgetRef ref) async {
  final changed = await _rec(ref).recommendAgain();
  if (!context.mounted) return;
  _reportAgain(context, ref, changed);
}

/// AI 장소 다른 곳으로 바꾸기 (이번만 빼기 + 다시 추천)
Future<void> replaceStopWithUndo(BuildContext context, WidgetRef ref, CourseStop stop) async {
  final changed = await _rec(ref).replaceAi(stop);
  if (!context.mounted) return;
  _reportAgain(context, ref, changed);
}

void _reportAgain(BuildContext context, WidgetRef ref, int? changed) {
  if (changed == null) {
    final error = ref.read(recommendationProvider).error;
    if (error == null) return; // 취소함 — 취소 버튼이 따로 알린다
    showAppSnackBar(context, '다시 추천하지 못했어요. ${failureMessage(error)}');
  } else if (changed == 0) {
    _undoSnack(context, ref, '바꿀 추천 장소를 찾지 못했어요');
  } else {
    _undoSnack(context, ref, '추천 장소 $changed곳을 바꿨어요');
  }
}

/// 편집 화면에서 타일을 누를 때: 앞으로 · 뒤로 · 이 코스에서 빼기 / (AI) 앞으로 추천하지 않기
void showEditTileSheet(BuildContext context, WidgetRef ref, CourseStop stop, int index) {
  final count = ref.read(recommendationProvider).stops.length;
  showEditStopSheet(
    context,
    stop: stop,
    onUp: index > 0 ? () => _rec(ref).moveStop(index, index - 1) : null,
    onDown: index < count - 1 ? () => _rec(ref).moveStop(index, index + 2) : null,
    onRemove: () => removeStopWithUndo(context, ref, stop),
    onBlock: stop.isAi ? () => blockStopWithUndo(context, ref, stop) : null,
  );
}

/// 장소 추가 화면 인자 (이미 코스에 있는 장소는 고를 수 없게)
AddPlacesArgs courseAddPlacesArgs(List<CourseStop> stops) => AddPlacesArgs(excludedPlaceIds: {for (final s in stops) s.place.id});

/// 4단계 결과에서 장소를 누를 때
void showResultSheet(BuildContext context, WidgetRef ref, CourseStop stop) {
  showResultStopSheet(
    context,
    stop: stop,
    onInfo: () => context.push(AppRoutes.place(stop.place.id)),
    onRemove: () => removeStopWithUndo(context, ref, stop),
    onSwap: stop.isAi ? () => replaceStopWithUndo(context, ref, stop) : null,
    onBlock: stop.isAi ? () => blockStopWithUndo(context, ref, stop) : null,
  );
}

/// 추천 취소 (4단계 대기 화면 · 다시 추천 중 줄). 취소했으면 true.
bool cancelRecommendationWithNotice(BuildContext context, WidgetRef ref) {
  final cancelled = _rec(ref).cancel();
  if (cancelled) showAppSnackBar(context, '추천을 취소했어요');
  return cancelled;
}
