import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/repositories.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/utils/external_link.dart';
import '../../../core/widgets/bottom_cta.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/widgets/headers.dart';
import '../../../core/widgets/map/apt_map.dart';
import '../../../core/widgets/map/map_pin.dart';
import '../../../core/widgets/overlays.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/surfaces.dart';
import '../../course/presentation/course_draft_controller.dart';
import '../../saved/presentation/saved_providers.dart';
import '../../saved/presentation/widgets/category_style.dart';
import '../../saved/presentation/widgets/collection_picker_sheet.dart';
import '../../saved/presentation/widgets/place_image.dart';
import '../../saved/presentation/widgets/saved_rows.dart';
import '../domain/place.dart';
import '../domain/place_timing.dart';
import 'widgets/place_action_tiles.dart';

/// #20 장소 상세: 일반 헤더(뒤로 · 장소 상세 · 공유) → 사진(있을 때) → 이름 카드(저장 버튼, 추천받은 곳이면 ✦ 코스 이름) →
/// 장소 정보(값이 있는 줄만) → 담은 보관함, 하단 고정 '이 장소로 코스 만들기'
class PlaceDetailPage extends ConsumerWidget {
  const PlaceDetailPage({super.key, required this.placeId});
  final String placeId;

  static const _photoHeight = 240.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(placeDetailProvider(placeId));
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 일반 헤더 (불러오는 중 · 오류에도 뒤로 갈 수 있다)
            // v2: 머리에 제목 없이 뒤로 · 공유만 (이름은 본문에 크게)
            PlainHeader(
              onLeading: () => popOrGoHome(context),
              actions: [
                IconButton(
                  tooltip: '공유',
                  // 공유 동작은 확정 필요 (docs/05 #20)
                  onPressed: () => showAppSnackBar(context, '장소 공유는 준비 중이에요.'),
                  icon: const Icon(Icons.ios_share_rounded, color: AppColors.textPrimary, size: 22),
                ),
              ],
            ),
            Expanded(
              child: AsyncValueView<PlaceDetail>(
                value: detail,
                onRetry: () => ref.invalidate(placeDetailProvider(placeId)),
                data: (d) => _Body(detail: d),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.detail});
  final PlaceDetail detail;

  Place get place => detail.place;

  Future<void> _changeCollections(BuildContext context) async {
    final ok = await showCollectionPickerSheet(
      context,
      places: [place],
      mode: place.isSaved ? CollectionPickerMode.change : CollectionPickerMode.save,
      initialSelected: detail.collectionIds.toSet(),
    );
    if (ok == true && context.mounted) showAppSnackBar(context, place.isSaved ? '보관함을 변경했어요.' : '장소를 저장했어요.');
  }

  /// 저장 버튼. 보관함이 없는 서버 모드에서 저장된 장소는 바로 저장을 해제하고 되돌리기를 준다 (07 D41).
  /// 그 밖에는 보관함 시트(저장 · 변경)를 연다.
  Future<void> _onSaveButton(BuildContext context, WidgetRef ref) async {
    if (!place.isSaved || ref.read(collectionsSupportedProvider)) return _changeCollections(context);
    // 해제 뒤 화면이 새로 그려져도 되돌리기가 동작하도록 미리 잡아 둔다
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(savedRepositoryProvider);
    final id = place.id;
    try {
      await repo.unsavePlace(id);
    } catch (e) {
      if (context.mounted) showAppSnackBar(context, failureMessage(e));
      return;
    }
    if (context.mounted) {
      showAppSnackBar(
        context,
        '저장을 해제했어요.',
        actionLabel: '되돌리기',
        onAction: () async {
          try {
            await repo.savePlaces(placeIds: [id], collectionIds: const []);
            invalidateSavedDataIn(container);
          } catch (e) {
            messenger.showSnackBar(SnackBar(content: Text(failureMessage(e))));
          }
        },
      );
    }
    invalidateSavedDataIn(container);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 서버 모드에는 보관함이 없다(목록이 비면 카드를 숨긴다)
    final collections = ref.watch(collectionsProvider).value ?? const [];
    final names = [
      for (final c in collections)
        if (detail.collectionIds.contains(c.id)) c.name,
    ];

    // 추천받아 저장된 곳이면 어느 코스에서 왔는지 (저장됨 AI 추천 탭과 같은 값, 07 D44)
    final aiItem = ref.watch(aiSavedPlacesProvider).value?.where((i) => i.place.id == place.id).firstOrNull;
    final recommendedIn = aiItem == null ? null : SavedPlaceRow.recommendedLabel(aiItem.recommendedIn);
    // 값이 없는 줄은 숨긴다 (추천받은 곳은 주소가 비어 있을 수 있다)
    final period = timingPeriod(place.timing);
    final hasPhoto = place.imageUrl != null && place.imageUrl!.isNotEmpty;
    final infoRows = <Widget>[
      if (place.address.trim().isNotEmpty)
        _InfoRow(
          label: '주소',
          child: Text(place.address, style: AppTypography.bodyMuted),
        ),
      if (place.phone != null)
        _InfoRow(
          label: '전화',
          onTap: () => openDialer(context, place.phone!),
          child: Text(place.phone!, style: AppTypography.bodyStrong),
        ),
      if (place.keywords.isNotEmpty)
        _InfoRow(
          label: '키워드',
          child: TagWrap(place.keywords, tone: AppTagTone.primary),
        ),
      if (place.mapUrl != null)
        _InfoRow(
          label: '지도',
          onTap: () => openExternalLink(context, place.mapUrl!),
          child: Text('카카오맵에서 보기', style: AppTypography.bodyStrong),
        ),
      if (place.sourceUrl != null)
        _InfoRow(
          label: '원본',
          onTap: () => openExternalLink(context, place.sourceUrl!),
          child: Text('Instagram 게시물', style: AppTypography.bodyStrong),
        ),
    ];

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            children: [
              // v2: 사진이 있으면 화면 폭 전체 사진, 없으면 업종 색 칸 + 이름 (서버 모드는 사진이 없다)
              if (hasPhoto) ...[
                PlaceImage(place: place, width: double.infinity, height: PlaceDetailPage._photoHeight, radius: 0, iconSize: 40),
                const SizedBox(height: AppSpacing.lg),
              ] else
                const SizedBox(height: AppSpacing.xxs),
              Padding(
                padding: AppSpacing.screenPadding,
                child: _TitleCard(detail: detail, recommendedIn: recommendedIn, hasPhoto: hasPhoto, onSave: () => _onSaveButton(context, ref)),
              ),
              if (period != null) ...[
                const SizedBox(height: 14),
                Padding(
                  padding: AppSpacing.screenPadding,
                  child: _PeriodPanel(period: period),
                ),
              ],
              if (place.location != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding: AppSpacing.screenPadding,
                  child: _LocationMap(place: place),
                ),
              ],
              if (infoRows.isNotEmpty) ...[
                const SectionHeader(title: '장소 정보', padding: EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.lg, AppSpacing.screenH, AppSpacing.xs)),
                // v2: 상자 없이 왼쪽 회색 이름표 + 값
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                  child: DividedRows(indent: SectionCard.innerPadding, children: infoRows),
                ),
              ],
              if (place.isSaved && collections.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding: AppSpacing.screenPadding,
                  child: SectionCard(
                    title: '담은 보관함',
                    trailing: TextButton(
                      onPressed: () => _changeCollections(context),
                      style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                      child: Text('변경', style: AppTypography.label.copyWith(color: AppColors.primary)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: SectionCard.innerPadding),
                      child: Text(names.isEmpty ? '아직 담은 보관함이 없어요' : names.join(' · '), style: names.isEmpty ? AppTypography.meta : AppTypography.bodyMuted),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        BottomCta(
          child: AppButton(
            label: '이 장소로 코스 만들기',
            icon: Icons.route_rounded,
            // 해당 장소를 사전 선택해 코스 만들기 1/4로 (docs/04 §D)
            onPressed: () => startCourseWizard(context, ref, places: [place]),
          ),
        ),
      ],
    );
  }
}

/// 이름 머리 (v2): (사진 없으면 업종 색 칸 64) · 업종 · 동네 · 이름 24 · 평점 · 영업 상태 → 행동 칸(저장 · 카카오맵 · 전화)
class _TitleCard extends StatelessWidget {
  const _TitleCard({required this.detail, required this.onSave, required this.hasPhoto, this.recommendedIn});
  final PlaceDetail detail;
  final VoidCallback onSave;
  final bool hasPhoto;

  /// "test3 코스에서 추천" — 추천받아 저장된 곳만 (✦ · 주황은 AI 추천 표시 전용)
  final String? recommendedIn;

  @override
  Widget build(BuildContext context) {
    final place = detail.place;
    final status = [if (place.rating != null) '★ ${place.rating!.toStringAsFixed(1)}', ?detail.openStatusLabel, ?detail.closingLabel].join(' · ');
    final kind = [place.categoryLabel, if (place.shortArea.isNotEmpty) place.shortArea].join(' · ');
    final names = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(kind, style: AppTypography.meta),
        Text(place.name, style: AppTypography.hero),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasPhoto)
          names
        else
          Row(
            children: [
              PlaceImage(place: place, width: 64, height: 64, radius: 18, iconSize: 28),
              const SizedBox(width: 14),
              Expanded(child: names),
            ],
          ),
        if (status.isNotEmpty) ...[const SizedBox(height: 4), Text(status, style: AppTypography.meta.copyWith(color: AppColors.textSecondary))],
        if (recommendedIn != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Text('✦', style: AppTypography.meta.copyWith(color: AppColors.ai)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '$recommendedIn받은 곳이에요',
                  style: AppTypography.caption.copyWith(color: AppColors.aiText, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        PlaceActionTiles(
          saved: place.isSaved,
          onSave: onSave,
          onMap: place.mapUrl == null ? null : () => openExternalLink(context, place.mapUrl!),
          onCall: place.phone == null ? null : () => openDialer(context, place.phone!),
        ),
      ],
    );
  }
}

/// 팝업 · 행사 · 신규 오픈 기간 (v2: 연파랑 판, 기간 굵게 · 확인한 날 · 방문 안내)
class _PeriodPanel extends StatelessWidget {
  const _PeriodPanel({required this.period});
  final TimingPeriod period;

  @override
  Widget build(BuildContext context) {
    final ended = period.ended;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: ended ? AppColors.fill : AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${period.label} ${period.value}', style: AppTypography.bodyStrong.copyWith(color: ended ? AppColors.textSecondary : AppColors.primary)),
          const SizedBox(height: 4),
          Text([period.note, ?period.tip].join(' '), style: AppTypography.meta.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// 이름 카드 아래 위치 지도 (움직이지 않는 작은 지도, 누르면 카카오맵). 정보 몇 줄 뒤 화면이 비어 보이지 않게, 나가기 전에 위치를 알 수 있게
class _LocationMap extends StatelessWidget {
  const _LocationMap({required this.place});
  final Place place;

  static const double _height = 150;

  @override
  Widget build(BuildContext context) {
    final style = CategoryStyle.of(place.categoryKey);
    final url = place.mapUrl;
    return SizedBox(
      height: _height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Stack(
          children: [
            Positioned.fill(
              child: AptMap(
                markers: [MapMarker(id: place.id, point: place.location!, kind: MapPinKind.place, icon: style.icon, color: style.color)],
              ),
            ),
            // 작은 지도는 움직이지 않고 누르면 카카오맵으로
            Positioned.fill(
              child: Semantics(
                button: url != null,
                label: url != null ? '${place.name} 위치, 카카오맵에서 보기' : '${place.name} 위치 지도',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: url == null ? null : () => openExternalLink(context, url),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.child, this.onTap});
  final String label;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: SectionCard.innerPadding, vertical: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(label, style: AppTypography.meta.copyWith(fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Align(alignment: Alignment.centerLeft, child: child),
          ),
          if (onTap != null) const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
        ],
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}
