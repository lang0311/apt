import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/repositories.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/widgets/overlays.dart';
import 'saved_providers.dart';

/// 저장됨에서 여러 곳을 골라 삭제하는 선택 모드 (07 D45).
/// 선택 중에는 앱 셸이 하단 탭을 숨기고 저장됨 화면이 그 자리에 삭제 버튼을 둔다.
class SavedSelectionState {
  const SavedSelectionState({this.active = false, this.ids = const {}, this.failed = const {}});

  final bool active;

  /// 고른 장소 id
  final Set<String> ids;

  /// 지난번 삭제에서 실패한 장소 id (행에 '삭제하지 못했어요')
  final Set<String> failed;
}

final savedSelectionProvider = NotifierProvider<SavedSelection, SavedSelectionState>(SavedSelection.new);

class SavedSelection extends Notifier<SavedSelectionState> {
  @override
  SavedSelectionState build() => const SavedSelectionState();

  /// 선택 모드 시작. 행을 길게 눌러 시작하면 그 행이 골라진 채로 시작한다.
  void start([String? id]) => state = SavedSelectionState(active: true, ids: {if (id != null) id});

  void toggle(String id) {
    final ids = {...state.ids};
    if (!ids.remove(id)) ids.add(id);
    state = SavedSelectionState(active: true, ids: ids, failed: state.failed);
  }

  /// 전체 선택 · 해제 (지금 보이는 목록 기준)
  void setAll(Iterable<String> ids, {required bool selected}) =>
      state = SavedSelectionState(active: true, ids: selected ? ids.toSet() : const {}, failed: state.failed);

  void exit() {
    if (state.active) state = const SavedSelectionState();
  }

  /// 일부만 지워졌을 때: 실패한 곳만 고른 채로 선택 모드를 유지한다
  void keepFailed(Set<String> failed) => state = SavedSelectionState(active: true, ids: failed, failed: failed);
}

/// 고른 장소를 한 곳씩 지운다 (서버에 한꺼번에 지우는 API가 없다).
/// [undoable]이면 다 지운 뒤 '되돌리기'로 다시 저장한다 — AI 추천 탭은 다시 저장하면 서버가
/// '직접 저장'으로 넣어 카테고리로 옮겨지므로 되돌리기를 주지 않는다 (07 D45).
Future<void> deleteSavedPlaces(BuildContext context, WidgetRef ref, {required List<String> ids, required bool undoable}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.of(context);
  final repo = ref.read(savedRepositoryProvider);
  final selection = ref.read(savedSelectionProvider.notifier);
  final withCollections = ref.read(collectionsSupportedProvider);

  // 보관함이 있으면(Mock) 되돌릴 때 원래 보관함에 다시 넣는다
  final collectionsOf = <String, List<String>>{};
  final deleted = <String>[];
  final failed = <String>{};
  for (final id in ids) {
    try {
      if (undoable && withCollections) collectionsOf[id] = await repo.fetchPlaceCollectionIds(id);
      await repo.unsavePlace(id);
      deleted.add(id);
    } catch (_) {
      failed.add(id);
    }
  }
  invalidateSavedDataIn(container);
  if (!context.mounted) return;

  if (failed.isEmpty) {
    selection.exit();
    showAppSnackBar(
      context,
      '${deleted.length}곳을 삭제했어요.',
      actionLabel: undoable ? '되돌리기' : null,
      onAction: !undoable
          ? null
          : () async {
              try {
                if (withCollections) {
                  for (final id in deleted) {
                    await repo.setPlaceCollections(placeId: id, collectionIds: collectionsOf[id] ?? const []);
                  }
                } else {
                  await repo.savePlaces(placeIds: deleted, collectionIds: const []);
                }
                invalidateSavedDataIn(container);
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text(failureMessage(e))));
              }
            },
    );
    return;
  }

  selection.keepFailed(failed);
  showAppSnackBar(
    context,
    deleted.isEmpty ? '삭제하지 못했어요.' : '${deleted.length}곳을 삭제했어요. ${failed.length}곳은 삭제하지 못했어요.',
    actionLabel: '다시 시도',
    onAction: () {
      if (context.mounted) deleteSavedPlaces(context, ref, ids: failed.toList(), undoable: undoable);
    },
  );
}
