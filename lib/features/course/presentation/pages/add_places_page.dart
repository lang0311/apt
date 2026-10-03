import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/bottom_cta.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/headers.dart';
import '../../../place/domain/place.dart';
import '../../../saved/presentation/widgets/saved_place_picker.dart';

class AddPlacesArgs {
  const AddPlacesArgs({
    this.title = '저장한 장소에서 추가',
    this.excludedPlaceIds = const {},
    this.ctaLabel = '선택한 장소 추가하기',
  });

  final String title;

  /// 이미 코스/보관함에 있는 장소
  final Set<String> excludedPlaceIds;
  final String ctaLabel;
}

/// #29 저장한 장소 추가 (풀 시트). 선택한 장소 목록을 pop 결과로 돌려준다.
/// 코스 동행 설정·AI 추천 편집·코스 상세·빈 보관함에서 공통으로 쓴다.
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
          children: [
            SubPageHeader(
              title: widget.args.title,
              trailing: AppTextLink(label: '완료', onPressed: _selected.isEmpty ? null : _done, color: AppColors.primary),
            ),
            Expanded(
              child: SavedPlacePicker(
                selectedIds: _selected.map((p) => p.id).toList(),
                onToggle: _toggle,
                style: PickerSelectionStyle.checkbox,
                excludedIds: widget.args.excludedPlaceIds,
                showSavedTag: true,
              ),
            ),
            BottomCta(
              child: AppButton(
                label: '${widget.args.ctaLabel} (${_selected.length})',
                onPressed: _selected.isEmpty ? null : _done,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
