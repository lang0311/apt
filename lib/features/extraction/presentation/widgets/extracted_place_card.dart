import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/chips.dart';
import '../../../../core/widgets/selection.dart';
import '../../../../core/widgets/surfaces.dart';
import '../../domain/extraction_models.dart';

/// 추출 결과 장소 카드. 이미 저장된 장소는 선택할 수 없다.
class ExtractedPlaceCard extends StatelessWidget {
  const ExtractedPlaceCard({super.key, required this.item, required this.selected, required this.onTap});

  final ExtractedPlace item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = item.place;
    final disabled = item.alreadySaved;
    return Semantics(
      selected: selected,
      enabled: !disabled,
      child: AppCard(
        onTap: disabled ? null : onTap,
        borderColor: selected ? AppColors.primary : null,
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppNetworkImage(url: p.imageUrl, width: 104, height: 116, radius: 16),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(p.name, style: AppTypography.section, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      RadioDot(selected: selected, enabled: !disabled),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('${p.displayArea} · ${p.categoryLabel}', style: AppTypography.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (p.keywords.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(p.keywords.take(2).join(' · '), style: AppTypography.label.copyWith(color: AppColors.primary)),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  if (disabled)
                    const AppTag('이미 저장됨')
                  else if (selected)
                    const AppTag('저장할 장소', tone: AppTagTone.primary, icon: Icons.check_rounded),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
