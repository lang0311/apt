import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';

/// 앱 로고 (다크 라운드 사각 + 우산형 심볼) + 카피
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 56, this.showCopy = true});
  final double size;
  final bool showCopy;

  static const copy = '가고 싶은 곳을, 하나의 코스로.';

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(size * 0.3)),
          child: CustomPaint(painter: _LogoPainter()),
        ),
        if (showCopy) ...[
          const SizedBox(height: 18),
          Text(copy, style: AppTypography.cardTitle.copyWith(fontSize: 17), textAlign: TextAlign.center),
        ],
      ],
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.045
      ..strokeCap = StrokeCap.round;
    final c = Offset(size.width / 2, size.height * 0.58);
    final r = size.width * 0.27;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), 3.4, 2.62, false, p);
    canvas.drawLine(Offset(c.dx, size.height * 0.27), Offset(c.dx, size.height * 0.75), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
