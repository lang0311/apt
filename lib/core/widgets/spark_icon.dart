import 'package:flutter/material.dart';

/// AI 추천 표시 ✦ (리디자인 v2 시안의 속이 찬 4각 별). Lucide sparkle은 속이 빈 선이라 시안 모양을 직접 그린다.
/// ✦는 AI 추천 표시로만 쓴다 (07 D17).
class SparkIcon extends StatelessWidget {
  const SparkIcon({super.key, this.size = 16, this.color, this.semanticLabel});

  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? Colors.black;
    final star = SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _SparkPainter(c)),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: star);
    return Semantics(label: semanticLabel, child: star);
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // 시안 path (24칸): M12 2.5 14 10l7.5 2-7.5 2-2 7.5-2-7.5-7.5-2L10 10z
    final s = size.width / 24;
    final p = Path()
      ..moveTo(12 * s, 2.5 * s)
      ..lineTo(14 * s, 10 * s)
      ..lineTo(21.5 * s, 12 * s)
      ..lineTo(14 * s, 14 * s)
      ..lineTo(12 * s, 21.5 * s)
      ..lineTo(10 * s, 14 * s)
      ..lineTo(2.5 * s, 12 * s)
      ..lineTo(10 * s, 10 * s)
      ..close();
    canvas.drawPath(
      p,
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.color != color;
}
