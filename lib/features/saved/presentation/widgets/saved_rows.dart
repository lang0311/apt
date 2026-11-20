import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/overlays.dart';
import '../../../place/domain/place.dart';
import '../../domain/saved_models.dart';
import 'category_style.dart';
import 'place_image.dart';
import 'source_chips.dart';

/// 저장 장소 한 행: 사진 56 · 이름 · '카테고리 · 동네' · ★평점/@출처(둘 다 없으면 셋째 줄 생략)
/// AI 추천 탭에서는 셋째 줄에 ✦ + 추천한 코스 이름(07 D44), 선택 모드에서는 왼쪽에 네모 체크(07 D45).
class SavedPlaceRow extends StatelessWidget {
  const SavedPlaceRow({
    super.key,
    required this.place,
    required this.onTap,
    this.onLongPress,
    this.selected,
    this.failed = false,
    this.recommendedIn,
    this.fromCourse = false,
  });
  final Place place;
  final VoidCallback onTap;

  /// 길게 누르면 선택 모드로 (이 행을 고른 채로)
  final VoidCallback? onLongPress;

  /// 선택 모드일 때만 값이 있다 (체크 표시)
  final bool? selected;

  /// 지난번 삭제에 실패한 행 ('삭제하지 못했어요')
  final bool failed;

  /// AI 추천 탭: 추천한 코스 이름 ([fromCourse]인데 이름을 모르면 null)
  final String? recommendedIn;

  /// AI 추천 탭의 행 (셋째 줄에 ✦ 추천 표시)
  final bool fromCourse;

  /// '연남 산책' → '연남 산책 코스에서 추천'. 이름이 이미 '코스'로 끝나면 덧붙이지 않는다.
  static String recommendedLabel(String? course) {
    if (course == null || course.trim().isEmpty) return '코스에서 추천';
    final name = course.trim();
    return name.endsWith('코스') ? '$name에서 추천' : '$name 코스에서 추천';
  }

  /// '서울 성동구 성수동' → '성수동', '서울 강서구 화곡로 416' → '강서구' (번지는 쓰지 않는다, [Place.shortArea])
  static String shortArea(Place p) => p.shortArea;

  /// 출처 계정을 '@계정' 꼴로. 없으면 null.
  static String? _handleOf(Place place) {
    final handle = place.sourceHandle;
    if (handle == null || handle.isEmpty) return null;
    return handle.startsWith('@') ? handle : '@$handle';
  }

  @override
  Widget build(BuildContext context) {
    final area = shortArea(place);
    final handle = _handleOf(place);
    final hasThird = !fromCourse && (place.rating != null || handle != null);
    final checked = selected;

    return Semantics(
      button: checked == null,
      checked: checked,
      label: [
        place.name,
        place.categoryLabel,
        area,
        if (place.rating != null) '평점 ${place.rating}',
        if (fromCourse) recommendedLabel(recommendedIn),
        if (failed) '삭제하지 못했어요',
      ].join(', '),
      excludeSemantics: true,
      child: Material(
        color: checked == true ? AppColors.primarySoft : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 76),
            child: Padding(
              padding: EdgeInsets.fromLTRB(checked == null ? AppSpacing.md : AppSpacing.sm, 10, AppSpacing.md, 10),
              child: Row(
                children: [
                  if (checked != null) ...[
                    SelectCheckbox(value: checked, onChanged: (_) => onTap()),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  PlaceImage(place: place, width: 56, height: 56),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(place.name, style: AppTypography.bodyStrong.copyWith(fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(
                          failed ? '삭제하지 못했어요' : [place.categoryLabel, if (area.isNotEmpty) area].join(' · '),
                          style: failed ? AppTypography.meta.copyWith(color: AppColors.dangerText) : AppTypography.meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (fromCourse) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.auto_awesome, size: 12, color: AppColors.ai),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  recommendedLabel(recommendedIn),
                                  style: AppTypography.caption.copyWith(color: AppColors.aiText, fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (hasThird) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              if (place.rating != null) ...[
                                const Icon(Icons.star_rounded, size: 13, color: AppColors.rating),
                                const SizedBox(width: 2),
                                Text(place.rating!.toStringAsFixed(1), style: AppTypography.caption.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                                const SizedBox(width: AppSpacing.xs),
                              ],
                              if (handle != null)
                                Flexible(child: Text(handle, style: AppTypography.caption, maxLines: 1, overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 선택 모드의 네모 체크 (행 · 전체 선택 공통, 07 D45). 누르는 영역은 행 전체라 체크 자체는 작게 둔다.
class SelectCheckbox extends StatelessWidget {
  const SelectCheckbox({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: 24,
        child: Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
          checkColor: Colors.white,
          side: const BorderSide(color: AppColors.controlBorder, width: 1.6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.tiny)),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

/// 보관함 한 행: 2×2 미니 콜라주 · 이름 · 'n곳 · 방금 수정' · ⋯
class CollectionRow extends StatelessWidget {
  const CollectionRow({super.key, required this.collection, required this.onTap, required this.onMore});
  final PlaceCollection collection;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final meta = [
      '${collection.placeCount}곳',
      if (collection.updatedAt != null) '${formatRecentDate(collection.updatedAt!)} 수정',
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 76),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 10, AppSpacing.xxs, 10),
          child: Row(
            children: [
              MiniCollage(urls: collection.thumbnailUrls),
              const SizedBox(width: 14),
              Expanded(
                child: Semantics(
                  button: true,
                  label: '${collection.name}, $meta',
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        collection.name,
                        style: AppTypography.bodyStrong.copyWith(fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(meta, style: AppTypography.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: onMore,
                tooltip: '${collection.name} 메뉴',
                icon: const Icon(Icons.more_horiz_rounded, color: AppColors.textSecondary),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 보관함 2열 표지 그리드 (리디자인 v2). 좌우 20 여백 · 칸 사이 10, 줄 사이 16
class CollectionGrid extends StatelessWidget {
  const CollectionGrid({super.key, required this.collections, required this.onOpen});
  final List<PlaceCollection> collections;
  final ValueChanged<PlaceCollection> onOpen;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < collections.length; i += 2) {
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: CollectionGridCard(collection: collections[i], onTap: () => onOpen(collections[i]))),
          const SizedBox(width: 10),
          Expanded(
            child: i + 1 < collections.length
                ? CollectionGridCard(collection: collections[i + 1], onTap: () => onOpen(collections[i + 1]))
                : const SizedBox.shrink(),
          ),
        ],
      ));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH - AppSpacing.xxs, AppSpacing.xxs, AppSpacing.screenH - AppSpacing.xxs, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[if (i > 0) const SizedBox(height: 16), rows[i]],
        ],
      ),
    );
  }
}

/// 그리드 한 칸: 정사각 표지 콜라주(모서리 16) · 이름 · 'n곳 · 수정'
class CollectionGridCard extends StatelessWidget {
  const CollectionGridCard({super.key, required this.collection, required this.onTap});
  final PlaceCollection collection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = collection.placeCount == 0
        ? '비어 있어요'
        : [
            '${collection.placeCount}곳',
            if (collection.updatedAt != null) formatRecentDate(collection.updatedAt!),
          ].join(' · ');
    return Semantics(
      button: true,
      label: '${collection.name}, $meta',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(builder: (context, c) => MiniCollage(urls: collection.thumbnailUrls, size: c.maxWidth, radius: 16)),
            const SizedBox(height: 8),
            Text(collection.name, style: AppTypography.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(meta, style: AppTypography.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

/// 썸네일 최대 4장, 모자라면 회색 칸, 0장이면 폴더 아이콘
class MiniCollage extends StatelessWidget {
  const MiniCollage({super.key, required this.urls, this.size = 56, this.radius = AppRadius.thumb});
  final List<String> urls;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: AppColors.fill, borderRadius: BorderRadius.circular(radius)),
        child: Icon(Icons.bookmark_border_rounded, color: AppColors.textTertiary, size: size > 80 ? 28 : 22),
      );
    }
    final cell = (size - 1.5) / 2;
    Widget tile(int index) {
      if (index < urls.length) return AppNetworkImage(url: urls[index], width: cell, height: cell, radius: 0);
      return Container(width: cell, height: cell, color: AppColors.surfaceMuted);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: Column(
          children: [
            Row(children: [tile(0), const SizedBox(width: 1.5), tile(1)]),
            const SizedBox(height: 1.5),
            Row(children: [tile(2), const SizedBox(width: 1.5), tile(3)]),
          ],
        ),
      ),
    );
  }
}

/// 보관함 탭의 '저장한 장소 전체 · n곳 ›' 줄 (07 D21 ②). 카드 안 카드로 보이지 않게 테두리 없는 목록 줄로 둔다
class AllPlacesLink extends StatelessWidget {
  const AllPlacesLink({super.key, required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '저장한 장소 전체 $count곳 보기',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xxs, AppSpacing.sm, AppSpacing.xs),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(AppRadius.small)),
                child: const Icon(Icons.bookmark_rounded, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('저장한 장소 전체', style: AppTypography.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('$count곳', style: AppTypography.meta),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}

/// 제목 줄 오른쪽 글자 버튼 ('필터', '+ 새 보관함'). [active]면 파란 글자 + 연파랑 바탕.
class HeaderTextButton extends StatelessWidget {
  const HeaderTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.active = false,
    this.primary = false,
    this.semanticLabel,
  });

  final String label;

  /// 없으면 글자만 ('선택', '완료')
  final IconData? icon;
  final VoidCallback onPressed;
  final bool active;

  /// 파란 글자(바탕 없음). '+ 새 보관함'에 쓴다.
  final bool primary;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final fg = active || primary ? AppColors.primary : AppColors.textPrimary;
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: Material(
        color: active ? AppColors.primarySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.small),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.small),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 17, color: fg),
                    const SizedBox(width: 4),
                  ],
                  Text(label, style: AppTypography.label.copyWith(color: fg)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 걸린 카테고리 칩 (남색, ×로 해제)
class AppliedFilterChip extends StatelessWidget {
  const AppliedFilterChip({super.key, required this.label, required this.onClear});
  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label 필터 해제',
      excludeSemantics: true,
      child: Material(
        color: AppColors.ink,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onClear,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 7, AppSpacing.xs, 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: AppTypography.label.copyWith(color: Colors.white)),
                const SizedBox(width: 2),
                const Icon(Icons.close_rounded, size: 15, color: Colors.white70),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 카테고리 시트: 서버 카테고리(아이콘 · 개수)를 **여러 개** 고른다(네모 체크, 07 D48).
/// 아래 `초기화`는 고른 것을 모두 풀고, `n곳 보기`가 [onApply]로 고른 키들을 넘기며 닫는다(비면 전체).
/// 그냥 닫으면 아무 일도 없다. 0곳은 고를 수 없다. 저장됨 · 코스 장소 고르기 · 저장 지도가 같이 쓴다.
/// [title] · [styleOf]를 바꾸면 같은 시트로 지역을 고른다(저장됨 지역별 보기, [styleOf]가 null을 주면 아이콘 칸 없이 이름 · 개수만). [sources]를 주면 맨 위에
/// 직접 저장 · 추천받은 곳 켜고 끄기가 붙고 `적용`을 누를 때 [onApplySources]로 넘긴다(07 D47, 칩을 시트 안으로).
Future<void> showCategoryFilterSheet(
  BuildContext context, {
  required SavedSummary summary,
  required Set<String> selected,
  required ValueChanged<Set<String>> onApply,
  String title = '카테고리',
  CategoryStyle? Function(String key)? styleOf,
  ({bool mine, bool ai})? sources,
  void Function(bool mine, bool ai)? onApplySources,
  bool? autoSearch,
  ValueChanged<bool>? onApplyAutoSearch,
}) {
  return showAppBottomSheet<void>(
    context,
    builder: (ctx) => _CategoryFilterSheet(
      summary: summary,
      initial: selected,
      onApply: onApply,
      title: title,
      styleOf: styleOf ?? CategoryStyle.of,
      sources: sources,
      onApplySources: onApplySources,
      autoSearch: autoSearch,
      onApplyAutoSearch: onApplyAutoSearch,
    ),
  );
}

class _CategoryFilterSheet extends StatefulWidget {
  const _CategoryFilterSheet({
    required this.summary,
    required this.initial,
    required this.onApply,
    required this.title,
    required this.styleOf,
    this.sources,
    this.onApplySources,
    this.autoSearch,
    this.onApplyAutoSearch,
  });
  final SavedSummary summary;
  final Set<String> initial;
  final ValueChanged<Set<String>> onApply;
  final String title;
  final CategoryStyle? Function(String key) styleOf;
  final ({bool mine, bool ai})? sources;
  final void Function(bool mine, bool ai)? onApplySources;

  /// 저장 지도의 '지도 이동 시 자동 검색' (주면 시트 맨 아래 스위치 한 줄)
  final bool? autoSearch;
  final ValueChanged<bool>? onApplyAutoSearch;

  @override
  State<_CategoryFilterSheet> createState() => _CategoryFilterSheetState();
}

class _CategoryFilterSheetState extends State<_CategoryFilterSheet> {
  // 요약에 없는 키(지운 뒤 사라진 카테고리)는 시트에서 고를 수 없으니 뺀다
  late final Set<String> _picked = {
    for (final k in widget.initial)
      if (widget.summary.categories.any((c) => c.key == k)) k,
  };

  late bool _mine = widget.sources?.mine ?? true;
  late bool _ai = widget.sources?.ai ?? true;
  late bool _auto = widget.autoSearch ?? true;

  int get _count => _picked.isEmpty
      ? widget.summary.totalCount
      : widget.summary.categories.where((c) => _picked.contains(c.key)).fold(0, (n, c) => n + c.count);

  @override
  Widget build(BuildContext context) {
    final maxList = MediaQuery.sizeOf(context).height * 0.6;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xxs, AppSpacing.lg, AppSpacing.xs),
            // 켜고 끄기가 붙으면 시트 제목은 '필터', 아래에 두 묶음 이름을 단다
            child: Text(widget.sources == null ? widget.title : '필터', style: AppTypography.section),
          ),
          if (widget.sources != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 0),
              child: Row(
                children: [
                  Expanded(child: Text('보여 줄 장소', style: AppTypography.label)),
                  SourceChips(
                    showMine: _mine,
                    showAi: _ai,
                    onChanged: ({bool? mine, bool? ai}) => setState(() {
                      _mine = mine ?? _mine;
                      _ai = ai ?? _ai;
                    }),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
              child: Text(widget.title, style: AppTypography.label),
            ),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxList),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final category in widget.summary.categories)
                    _CategoryOption(
                      label: category.label,
                      count: category.count,
                      style: widget.styleOf(category.key),
                      selected: _picked.contains(category.key),
                      onTap: category.count == 0
                          ? null
                          : () => setState(() => _picked.contains(category.key) ? _picked.remove(category.key) : _picked.add(category.key)),
                    ),
                ],
              ),
            ),
          ),
          if (widget.autoSearch != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.md, 0),
              child: Row(
                children: [
                  Expanded(child: Text('지도 이동 시 자동 검색', style: AppTypography.label)),
                  Switch(value: _auto, onChanged: (v) => setState(() => _auto = v)),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.sm, AppSpacing.screenH, AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: '초기화',
                    variant: AppButtonVariant.white,
                    height: 48,
                    onPressed: _picked.isEmpty && _mine && _ai
                        ? null
                        : () => setState(() {
                              _picked.clear();
                              _mine = true;
                              _ai = true;
                            }),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  flex: 2,
                  child: AppButton(
                    // 켜고 끄기가 붙으면 개수가 바뀌어 미리 셀 수 없다
                    label: widget.sources == null && widget.autoSearch == null ? '$_count곳 보기' : '적용',
                    height: 48,
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onApply(Set.unmodifiable(_picked));
                      widget.onApplySources?.call(_mine, _ai);
                      widget.onApplyAutoSearch?.call(_auto);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryOption extends StatelessWidget {
  const _CategoryOption({required this.label, required this.count, required this.style, required this.selected, required this.onTap});
  final String label;
  final int count;
  final CategoryStyle? style;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final style = this.style;
    return Semantics(
      button: true,
      checked: selected,
      enabled: enabled,
      label: '$label $count곳',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: SizedBox(
            height: style == null ? 48 : 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  if (style != null) ...[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: style.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.small)),
                      child: Icon(style.icon, size: 19, color: style.ink),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Text(
                    label,
                    style: AppTypography.bodyStrong.copyWith(
                      color: selected ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('$count', style: AppTypography.meta),
                  const Spacer(),
                  IgnorePointer(child: SelectCheckbox(value: selected, onChanged: (_) {})),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
