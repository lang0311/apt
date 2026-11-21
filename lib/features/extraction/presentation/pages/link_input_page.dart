import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/instagram_url.dart';
import '../../../../core/widgets/headers.dart';
import '../../../../core/widgets/inputs.dart';
import '../../../../core/widgets/surfaces.dart';
import '../../../saved/presentation/widgets/place_image.dart';
import '../extraction_providers.dart';
import '../widgets/extracted_place_card.dart';

/// #10 장소 추가 탭 (11-14 '추출'에서 이름 변경). 주 경로인 릴스 공유 3단계를 맨 위에 두고,
/// 링크 붙여 넣기 · 지도에서 검색하기는 '다른 방법'으로 묶고, 아래에 최근 추가한 곳을 보여 준다.
/// 공유로 들어오면 이 화면을 건너뛴다. 링크 줄은 찾는 중 · 찾은 장소 화면의 링크 줄과 같은 모양이다 (07 D26).
class LinkInputPage extends ConsumerStatefulWidget {
  const LinkInputPage({super.key});

  @override
  ConsumerState<LinkInputPage> createState() => _LinkInputPageState();
}

class _LinkInputPageState extends ConsumerState<LinkInputPage> {
  final _url = TextEditingController();
  final _focus = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _url.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final url = InstagramUrl.extract(_url.text);
    if (url == null) {
      setState(() => _error = '인스타그램 게시물 또는 릴스 링크를 넣어 주세요.');
      return;
    }
    FocusScope.of(context).unfocus();
    context.push(AppRoutes.extractResult(url));
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _url.text.trim().isNotEmpty;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          children: [
            const PageTitleHeader(title: '장소 추가'),
            Padding(
              padding: AppSpacing.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ExtractSourceRow(
                    focused: _focus.hasFocus,
                    leading: const LinkTile(),
                    action: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasText)
                          IconButton(
                            tooltip: '지우기',
                            onPressed: () => setState(() {
                              _url.clear();
                              _error = null;
                            }),
                            icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textTertiary),
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 44),
                          ),
                        SourceRowAction(label: '찾기', onPressed: hasText ? _submit : null),
                      ],
                    ),
                    child: TextField(
                      controller: _url,
                      focusNode: _focus,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.go,
                      style: AppTypography.bodyStrong,
                      decoration: InputDecoration(
                        hintText: '인스타그램 링크 붙여넣기',
                        hintStyle: AppTypography.bodyMuted.copyWith(color: AppColors.textTertiary),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onChanged: (_) => setState(() => _error = null),
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.xs, AppSpacing.xs, 0),
                      child: AppFieldError(_error!),
                    ),
                  // 링크를 모를 때: 가게 이름으로 지도에서 찾기 (07 D32)
                  Semantics(
                    button: true,
                    label: '지도에서 검색하기',
                    excludeSemantics: true,
                    onTap: () => context.push(AppRoutes.placeSearch),
                    child: InkWell(
                      borderRadius: AppRadius.cardAll,
                      onTap: () => context.push(AppRoutes.placeSearch),
                      child: const _SearchRowLabel(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const _ReelsGuide(),
                ],
              ),
            ),
            const _RecentAdded(),
          ],
        ),
      ),
    );
  }
}

/// 최근 추가한 곳 (다섯 곳까지). 없으면 섹션째 숨긴다
class _RecentAdded extends ConsumerWidget {
  const _RecentAdded();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentExtractionsProvider).value ?? const [];
    if (recent.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xxs, AppSpacing.md, AppSpacing.xxs, 0),
      child: SectionCard(
        title: '최근 추가한 장소',
        actionLabel: '모두 보기',
        onAction: () => context.go(AppRoutes.saved),
        child: DividedRows(
          indent: SectionCard.innerPadding + 44 + AppSpacing.sm,
          children: [
            for (final r in recent.take(5))
              InkWell(
                onTap: () => context.push(AppRoutes.place(r.place.id)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: SectionCard.innerPadding, vertical: 8),
                  child: Row(
                    children: [
                      PlaceImage(place: r.place, width: 44, height: 44, radius: 12, iconSize: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.place.name, style: AppTypography.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(
                              [r.place.categoryLabel, if (r.place.shortArea.isNotEmpty) r.place.shortArea].join(' · '),
                              style: AppTypography.caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Text(formatRecentDate(r.extractedAt), style: AppTypography.caption),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchRowLabel extends StatelessWidget {
  const _SearchRowLabel();

  @override
  Widget build(BuildContext context) {
    // v2: 연파랑 아이콘 칸 · 제목 · 설명 · ›
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.map_outlined, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('지도에서 찾기', style: AppTypography.bodyStrong),
                Text('이름이나 주소로 검색해 저장', style: AppTypography.meta),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
        ],
      ),
    );
  }
}

/// 릴스에서 저장하는 방법 (v2: 채움 판 + 흰 칸 세 개)
class _ReelsGuide extends StatelessWidget {
  const _ReelsGuide();

  @override
  Widget build(BuildContext context) {
    Widget step(int n, String text) => Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: Text(
                '$n',
                style: AppTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700, height: 1),
              ),
            ),
            const SizedBox(height: 10),
            Text(text, style: AppTypography.label, maxLines: 2),
          ],
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(color: AppColors.fill, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('릴스에서 바로 저장하는 게 가장 빨라요', style: AppTypography.lead),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              step(1, '⋯ 누르기'),
              const SizedBox(width: AppSpacing.xs),
              step(2, '공유 → APT'),
              const SizedBox(width: AppSpacing.xs),
              step(3, '장소 저장'),
            ],
          ),
        ],
      ),
    );
  }
}
