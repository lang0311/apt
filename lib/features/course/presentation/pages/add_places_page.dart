import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/bottom_cta.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/headers.dart';
import '../../../place/domain/place.dart';
import '../widgets/map_place_picker.dart';

class AddPlacesArgs {
  const AddPlacesArgs({
    this.title = '장소 추가',
    this.excludedPlaceIds = const {},
    this.excludedLabel = '코스에 있음',
    this.ctaLabel = '일정에 추가',
  });

  final String title;

  /// 이미 코스/보관함에 있는 장소 — 흐리게 + [excludedLabel], 고를 수 없다
  final Set<String> excludedPlaceIds;
  final String excludedLabel;
  final String ctaLabel;
}

/// #29 저장한 장소 추가. 만들기 3단계와 같은 지도 화면(진행 바 없음)에서 고르고, 고른 장소를 pop 결과로 돌려준다.
/// 코스 편집(편집 → 일정 맨 아래 "장소 추가")·4단계 편집·빈 보관함에서 같이 쓴다.
class AddPlacesPage extends StatefulWidget {
  const AddPlacesPage({super.key, required this.args});
  final AddPlacesArgs args;

  @override
  State<AddPlacesPage> createState() => _AddPlacesPageState();
}

class _AddPlacesPageState extends State<AddPlacesPage> {
  final _selected = <Place>[];

  void _toggle(Place p) => setState(() {
        final i = _selected.indexWhere((s) => s.id == p.id);
        i >= 0 ? _selected.removeAt(i) : _selected.add(p);
      });

  void _done() => context.pop(List<Place>.unmodifiable(_selected));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PlainHeader(title: widget.args.title),
            Expanded(
              child: MapPlacePicker(
                selectedIds: _selected.map((p) => p.id).toList(),
                onToggle: _toggle,
                excludedIds: widget.args.excludedPlaceIds,
                excludedLabel: widget.args.excludedLabel,
              ),
            ),
            BottomCta(
              child: Row(
                children: [
                  if (_selected.isNotEmpty) ...[
                    PickedTray(places: _selected),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(child: AppButton(label: widget.args.ctaLabel, onPressed: _selected.isEmpty ? null : _done)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
