import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/instagram_url.dart';
import '../../../../core/widgets/bottom_cta.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/headers.dart';
import '../../../../core/widgets/inputs.dart';
import '../../../../core/widgets/overlays.dart';
import '../../../../core/widgets/selection.dart';
import '../../../../core/widgets/surfaces.dart';

/// #10 링크 입력 (폴백). 주 경로는 릴스 "공유 → 우리 앱"이며, 공유로 들어오면 이 화면을 건너뛴다.
class LinkInputPage extends StatefulWidget {
  const LinkInputPage({super.key});

  @override
  State<LinkInputPage> createState() => _LinkInputPageState();
}

class _LinkInputPageState extends State<LinkInputPage> {
  final _url = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      showAppSnackBar(context, '클립보드가 비어 있어요.');
      return;
    }
    final url = InstagramUrl.extract(text);
    setState(() {
      _url.text = url ?? text;
      _error = url == null ? '인스타그램 게시물 링크가 아니에요.' : null;
    });
  }

  void _submit() {
    final url = InstagramUrl.extract(_url.text);
    if (url == null) {
      setState(() => _error = '인스타그램 게시물 또는 릴스 링크를 입력해주세요.');
      return;
    }
    FocusScope.of(context).unfocus();
    context.push(AppRoutes.extractResult(url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  const PageTitleHeader(title: '장소 추출', subtitle: '마음에 든 공간, 링크 하나로 저장하세요.'),
                  Padding(
                    padding: AppSpacing.screenPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppCard(
                          color: AppColors.primarySoft,
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
                                child: const Icon(Icons.link_rounded, color: AppColors.primary),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text('인스타그램에서 발견한 장소', style: AppTypography.section),
                              const SizedBox(height: 4),
                              Text('게시물 링크를 붙여넣으면 장소를 찾아드려요.', style: AppTypography.body),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        AppTextField(
                          controller: _url,
                          label: '인스타그램 링크',
                          hint: 'https://www.instagram.com/...',
                          prefixIcon: Icons.link_rounded,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.go,
                          hasError: _error != null,
                          onChanged: (_) => setState(() => _error = null),
                          onSubmitted: (_) => _submit(),
                        ),
                        if (_error != null) ...[const SizedBox(height: AppSpacing.xs), AppFieldError(_error!)],
                        const SizedBox(height: AppSpacing.sm),
                        AppButton(
                          label: '클립보드에서 붙여넣기',
                          icon: Icons.content_paste_rounded,
                          variant: AppButtonVariant.soft,
                          onPressed: _paste,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Text('이렇게 이용해 보세요', style: AppTypography.cardTitle),
                        const SizedBox(height: AppSpacing.sm),
                        for (final (i, step) in const [
                          '인스타그램 게시물의 링크를 복사해요.',
                          '링크를 붙여넣고 장소를 추출해요.',
                          '원하는 장소를 선택해 저장해요.',
                        ].indexed)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: Row(
                              children: [
                                NumberBadge(i + 1, size: 26, color: AppColors.primarySoft, textColor: AppColors.primary),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(child: Text(step, style: AppTypography.body)),
                              ],
                            ),
                          ),
                        const SizedBox(height: AppSpacing.xs),
                        Text('공개 게시물만 지원해요. 장소 정보는 다를 수 있어요.', style: AppTypography.caption),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            BottomCta(
              child: AppButton(label: '장소 추출하기', onPressed: _url.text.trim().isEmpty ? null : _submit),
            ),
          ],
        ),
      ),
    );
  }
}
