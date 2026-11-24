import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/map/apt_map.dart';
import '../../../../core/widgets/map/map_pin.dart';
import '../../../saved/presentation/widgets/place_image.dart';
import '../../domain/course_models.dart';
import '../widgets/course_route_map.dart';

/// 코스 지도 크게 보기에 넘기는 값 (코스 상세 · 코스 만들기 4/4의 작은 지도에서 연다)
class CourseMapArgs {
  const CourseMapArgs({required this.title, required this.stops});
  final String title;
  final List<CourseStop> stops;
}

/// 코스 지도 전체 화면: 번호 핀 · AI ✦ 핀 · 장소를 직선으로 이은 선 + 아래 가로 장소 카드.
/// 경로선은 팀 서버가 장소 좌표만 줘서 직선이다 (도로를 따르는 경로는 NEEDS BACKEND, 06 §7).
class CourseRouteMapPage extends StatefulWidget {
  const CourseRouteMapPage({super.key, required this.args});
  final CourseMapArgs args;

  @override
  State<CourseRouteMapPage> createState() => _CourseRouteMapPageState();
}

class _CourseRouteMapPageState extends State<CourseRouteMapPage> {
  static const _cardHeight = 70.0;
  static const _topBar = 40.0;

  final _map = AptMapController();
  final _pages = PageController(viewportFraction: 0.64);
  late final _mappable = mappableStops(widget.args.stops);
  late final List<CourseStop> _stops = [for (final (s, _) in _mappable) s];
  late final List<int> _numbers = [for (final (_, n) in _mappable) n];
  String? _focusedId;

  @override
  void initState() {
    super.initState();
    if (_stops.isNotEmpty) _focusedId = _stops.first.place.id;
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _focus(int index, {bool scrollCards = false}) {
    final place = _stops[index].place;
    setState(() => _focusedId = place.id);
    _map.moveTo(place.location!, zoom: 15);
    if (scrollCards && _pages.hasClients) {
      _pages.animateToPage(index, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
    }
  }

  void _fitAll() {
    _map.fitTo([for (final s in _stops) s.place.location!]);
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context);
    final markers = [
      for (final (i, s) in _stops.indexed)
        MapMarker(id: s.place.id, point: s.place.location!, kind: s.isAi ? MapPinKind.ai : MapPinKind.numbered, number: _numbers[i]),
    ];
    final cardsBottom = inset.bottom + AppSpacing.sm;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AptMap(
              markers: markers,
              route: [for (final s in _stops) s.place.location!],
              selectedId: _focusedId,
              controller: _map,
              topPadding: inset.top + _topBar + AppSpacing.xs * 2,
              bottomPadding: cardsBottom + _cardHeight + 44,
              onMarkerTap: (m) {
                final i = _stops.indexWhere((s) => s.place.id == m.id);
                if (i >= 0) _focus(i, scrollCards: true);
              },
            ),
          ),
          Positioned(
            left: AppSpacing.sm,
            right: AppSpacing.sm,
            top: inset.top + AppSpacing.xs,
            child: Row(
              children: [
                _RoundButton(icon: LucideIcons.arrowLeft, tooltip: '뒤로', onPressed: () => context.pop()),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: _TitlePill(title: widget.args.title, count: _stops.length),
                ),
              ],
            ),
          ),
          Positioned(
            right: AppSpacing.sm,
            top: inset.top + AppSpacing.xs + _topBar + AppSpacing.xs,
            child: _RoundButton(icon: LucideIcons.scan, tooltip: '전체 보기', size: 44, onPressed: _fitAll),
          ),
          Positioned(left: AppSpacing.sm, bottom: cardsBottom + _cardHeight + AppSpacing.xs, child: const _LineNote()),
          Positioned(
            left: 0,
            right: 0,
            bottom: cardsBottom,
            height: _cardHeight,
            // 넘긴 카드가 늘 왼쪽 여백에서 시작하도록 PageView를 여백 안에 두고, 지나간 카드는 밖으로 그린다 (코스 만들기 3/4와 같은 방식)
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: PageView.builder(
                clipBehavior: Clip.none,
                controller: _pages,
                padEnds: false,
                itemCount: _stops.length,
                onPageChanged: _focus,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: _StopCard(
                    stop: _stops[i],
                    number: _numbers[i],
                    focused: _stops[i].place.id == _focusedId,
                    onTap: () => _focus(i, scrollCards: true),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _floatShadow = [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 2))];

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.onPressed, this.size = 40});
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: _floatShadow),
      child: SizedBox.square(
        dimension: size,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, size: 21, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _TitlePill extends StatelessWidget {
  const _TitlePill({required this.title, required this.count});
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    // alignment를 주면 폭이 화면 끝까지 늘어나므로 세로 여백으로 높이 40을 맞춘다 (글자 폭만큼만)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.large), boxShadow: _floatShadow),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: title),
            TextSpan(
              text: '  $count곳',
              style: AppTypography.meta.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
        style: AppTypography.bodyStrong.copyWith(fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// 경로선이 도로를 따르지 않고 장소끼리 직선이라는 안내 (서버가 도로 경로를 주면 없앤다)
class _LineNote extends StatelessWidget {
  const _LineNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: AppColors.mapPill, borderRadius: BorderRadius.circular(AppRadius.large), boxShadow: AppShadow.soft),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 3,
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 6),
          Text('장소를 직선으로 이어 보여 줘요', style: AppTypography.caption),
        ],
      ),
    );
  }
}

/// 지도 아래 가로 카드 (높이 70). 사진 위 왼쪽 위에 순서 번호 · AI 표시
class _StopCard extends StatelessWidget {
  const _StopCard({required this.stop, required this.number, required this.focused, required this.onTap});
  final CourseStop stop;
  final int number;
  final bool focused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final place = stop.place;
    final radius = BorderRadius.circular(AppRadius.medium);
    return Material(
      color: AppColors.surfaceRaised,
      elevation: 2,
      shadowColor: AppColors.shadowFloat,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: focused ? AppColors.primary : Colors.transparent, width: 1.5),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  PlaceImage(place: place, width: 44, height: 44, radius: 10, iconSize: 20),
                  Positioned(
                    left: -6,
                    top: -6,
                    child: _Badge(number: number, ai: stop.isAi),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(place.name, style: AppTypography.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(place.categoryLabel, style: AppTypography.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 번호 원. AI 추천은 주황, 내가 고른 곳은 파랑 (번호는 일정 순서대로 이어진다, 07 D62)
class _Badge extends StatelessWidget {
  const _Badge({required this.number, required this.ai});
  final int number;
  final bool ai;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ai ? AppColors.ai : AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Text(
        '$number',
        style: AppTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700, height: 1),
      ),
    );
  }
}
