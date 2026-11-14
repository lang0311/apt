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
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 주 경로: 릴스에서 공유 (순서가 있어 번호를 붙인다)
                  SectionCard(
                    title: '릴스에서 바로 저장하기',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: Column(
                        children: const [
                          _GuideRow(step: 1, icon: Icons.share_outlined, text: '릴스에서 공유를 눌러요'),
                          _GuideRow(step: 2, icon: Icons.more_horiz_rounded, text: '앱 목록에서 APT를 골라요'),
                          _GuideRow(step: 3, icon: Icons.check_rounded, text: '찾은 장소를 확인하고 저장해요'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.xs, 0, AppSpacing.xs, AppSpacing.xs),
                    child: Text('다른 방법', style: AppTypography.section),
                  ),
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
                        hintText: '링크를 붙여 넣어 주세요',
                        hintStyle: AppTypography.body.copyWith(color: AppColors.textTertiary),
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
                  const SizedBox(height: AppSpacing.sm),
                  // 링크를 모를 때: 가게 이름으로 지도에서 찾기 (07 D32)
                  Semantics(
                    button: true,
                    label: '지도에서 검색하기',
                    excludeSemantics: true,
                    onTap: () => context.push(AppRoutes.placeSearch),
                    child: InkWell(
                      borderRadius: AppRadius.cardAll,
                      onTap: () => context.push(AppRoutes.placeSearch),
                      child: const ExtractSourceRow(
                        leading: LinkTile(icon: Icons.search_rounded),
                        action: Padding(
                          padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                          child: Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
                        ),
                        child: _SearchRowLabel(),
                      ),
                    ),
                  ),
                  const _RecentAdded(),
                ],
              ),
            ),
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
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: SectionCard(
        title: '최근 추가한 곳',
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text('지도에서 검색하기', style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
    );
  }
}

class _GuideRow extends StatelessWidget {
  const _GuideRow({required this.step, required this.icon, required this.text});
  final int step;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(AppRadius.small),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, size: 17, color: AppColors.textPrimary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: '$step  ', style: AppTypography.bodyStrong.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800)),
                TextSpan(text: text),
              ]),
              style: AppTypography.bodyStrong.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
