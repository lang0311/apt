import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/repositories.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/inputs.dart';
import '../../../../core/widgets/overlays.dart';
import '../../../../core/widgets/surfaces.dart';
import '../../domain/saved_models.dart';
import '../saved_providers.dart';

/// #15 새 보관함 만들기 모달. 만든 보관함을 돌려준다.
Future<PlaceCollection?> showCreateCollectionModal(BuildContext context) {
  return showAppModal<PlaceCollection>(
    context,
    title: '새 보관함 만들기',
    builder: (_) => const _CreateCollectionForm(),
  );
}

class _CreateCollectionForm extends ConsumerStatefulWidget {
  const _CreateCollectionForm();

  @override
  ConsumerState<_CreateCollectionForm> createState() => _CreateCollectionFormState();
}

class _CreateCollectionFormState extends ConsumerState<_CreateCollectionForm> {
  static const _maxLength = 30;
  final _name = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final created = await ref.read(savedRepositoryProvider).createCollection(_name.text.trim());
      invalidateSavedData(ref);
      if (mounted) Navigator.of(context).pop(created);
    } on ValidationFailure catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      if (mounted) showAppSnackBar(context, failureMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _name.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          controller: _name,
          label: '보관함 이름',
          hint: '예: 서울 가을 산책',
          maxLength: _maxLength,
          showCounter: true,
          autofocus: true,
          hasError: _error != null,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => name.isEmpty ? null : _submit(),
        ),
        if (_error != null) ...[const SizedBox(height: AppSpacing.xs), AppFieldError(_error!)],
        const SizedBox(height: AppSpacing.md),
        AppCard(
          color: AppColors.bg,
          child: Row(
            children: [
              const IconCircle(icon: Icons.folder_outlined),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.isEmpty ? '보관함 이름' : name, style: AppTypography.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('코스 생성 시 한 번에 불러올 수 있어요.', style: AppTypography.caption),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: AppButton.outline(label: '취소', onPressed: () => Navigator.of(context).pop()),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              flex: 3,
              child: AppButton(label: '보관함 만들기', loading: _submitting, onPressed: name.isEmpty ? null : _submit),
            ),
          ],
        ),
      ],
    );
  }
}
