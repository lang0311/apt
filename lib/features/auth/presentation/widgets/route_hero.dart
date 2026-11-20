import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';

/// 로그인 위쪽 노선 그림 (리디자인 v2): 저장한 곳 → AI가 고른 곳을 선 하나로 잇는다.
/// 정거장 = 번호 원 + 이름을 흰 알약 하나로 묶는다. 위치는 폭 360 · 높이 210 기준 비율.
class RouteHero extends StatelessWidget {
  const RouteHero({super.key});

  static const height = 210.0;

  // (x, y) 번호 원 가운데, 폭 360 기준
  static const _stops = [
    (40.0, 170.0, '1', '릴스에서 본 카페', false),
    (180.0, 115.0, '2', '서울숲 산책', false),
    (320.0, 62.0, '3', '✦ AI가 고른 저녁', true),
  ];

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: ColoredBox(
          color: AppColors.primarySoft,
          child: LayoutBuilder(
            builder: (context, c) {
              final k = c.maxWidth / 360;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(child: CustomPaint(painter: _LinePainter(k))),
                  for (final (x, y, n, label, ai) in _stops)
                    Positioned(
                      top: y - 19,
                      left: ai ? null : x * k - 19,
                      right: ai ? c.maxWidth - x * k - 19 : null,
                      child: _Station(number: n, label: label, ai: ai),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Station extends StatelessWidget {
  const _Station({required this.number, required this.label, required this.ai});
  final String number;
  final String label;
  final bool ai;

  @override
  Widget build(BuildContext context) {
    final circle = Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: ai ? AppColors.ai : AppColors.primary, shape: BoxShape.circle),
      child: Text(
        number,
        style: AppTypography.label.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
    final text = Text(label, style: AppTypography.label.copyWith(color: ai ? AppColors.aiText : AppColors.textPrimary));
    return Container(
      padding: ai ? const EdgeInsets.fromLTRB(12, 3, 3, 3) : const EdgeInsets.fromLTRB(3, 3, 12, 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [BoxShadow(color: Color(0x1A132238), blurRadius: 10, offset: Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ai ? [text, const SizedBox(width: 8), circle] : [circle, const SizedBox(width: 8), text],
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.k);
  final double k;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(40 * k, 170)
      ..cubicTo(110 * k, 170, 110 * k, 115, 180 * k, 115)
      ..cubicTo(250 * k, 115, 250 * k, 62, 320 * k, 62);
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.k != k;
}
